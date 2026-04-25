/*

 [The "BSD licence"]
 Copyright (c) 2003-2006 Arizona Software
 All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 1. Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 3. The name of the author may not be used to endorse or promote products
 derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
															   NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
															   DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

 */

#import "AudioFileImporter.h"
#import "AudioDialogPrefs.h"
#import "AudioConstants.h"

#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>

// Output format the rest of the app expects: 32-bit float, 44.1 kHz,
// non-interleaved, mono or stereo. AudioDataAmplitude assumes
// SOUND_DEFAULT_RATE (44100) when -setDataBuffer:size:channel: is used.
static const Float64 kImportTargetRate = 44100.0;
static const UInt32  kImportReadFrames = 8192;

@interface AudioFileImporter ()
- (void)decodeOnBackgroundThread;
- (void)finishWithAmplitude:(AudioDataAmplitude *)amplitude;
- (void)failWithMessage:(NSString *)message;
- (void)updateProgress:(NSNumber *)fraction;
@end

@implementation AudioFileImporter

- (id)init
{
    if ((self = [super init])) {
        mProgressPanel = NULL;
        mSourceFile    = NULL;
        mAmplitude     = NULL;
        mErrorMessage  = [[NSMutableString string] retain];
        mDelegate      = NULL;
        mCancelFlag    = NO;
    }
    return self;
}

- (void)dealloc
{
    [mSourceFile release];
    [mAmplitude release];
    [mErrorMessage release];
    [super dealloc];
}

- (NSString*)errorMessage { return mErrorMessage; }
- (NSString*)sourceFile   { return mSourceFile; }

- (BOOL)amplitudeFromAnyFile:(NSString*)sourceFile delegate:(id)delegate parentWindow:(NSWindow*)window
{
    mSourceFile = [sourceFile retain];
    mDelegate   = delegate;

    mProgressPanel = [[ARProgressPanel progressPanelWithParentWindow:window delegate:self] retain];
    [mProgressPanel setProgressPrompt:NSLocalizedString(@"Reading audio file...", NULL)];
    [mProgressPanel setProgressValue:0.0];
    [mProgressPanel setDeterminate:YES];
    [mProgressPanel setCancelButtonEnabled:YES];
    [mProgressPanel open];

    [NSThread detachNewThreadSelector:@selector(decodeOnBackgroundThread)
                             toTarget:self
                           withObject:nil];
    return YES;
}

- (void)progressPanelCancelled:(id)progressPanel
{
    mCancelFlag = YES;
}

#pragma mark - Decode

- (void)decodeOnBackgroundThread
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    ExtAudioFileRef file = NULL;
    float *leftBuffer  = NULL;
    float *rightBuffer = NULL;
    UInt32 outChannels = 0;
    BOOL ok = NO;

    NSURL *url = [NSURL fileURLWithPath:mSourceFile];
    OSStatus err = ExtAudioFileOpenURL((CFURLRef)url, &file);
    if (err != noErr) {
        [self failWithMessage:[NSString stringWithFormat:
            NSLocalizedString(@"Could not open the audio file (error %d).", NULL), (int)err]];
        goto cleanup;
    }

    AudioStreamBasicDescription fileFormat;
    UInt32 size = sizeof(fileFormat);
    err = ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileDataFormat, &size, &fileFormat);
    if (err != noErr) {
        [self failWithMessage:NSLocalizedString(@"Could not read the audio file format.", NULL)];
        goto cleanup;
    }

    outChannels = (fileFormat.mChannelsPerFrame >= 2) ? 2 : 1;

    AudioStreamBasicDescription clientFormat;
    memset(&clientFormat, 0, sizeof(clientFormat));
    clientFormat.mSampleRate       = kImportTargetRate;
    clientFormat.mFormatID         = kAudioFormatLinearPCM;
    clientFormat.mFormatFlags      = kAudioFormatFlagIsFloat
                                   | kAudioFormatFlagIsPacked
                                   | kAudioFormatFlagIsNonInterleaved;
    clientFormat.mBitsPerChannel   = 32;
    clientFormat.mChannelsPerFrame = outChannels;
    clientFormat.mFramesPerPacket  = 1;
    clientFormat.mBytesPerFrame    = sizeof(float);   // per channel (non-interleaved)
    clientFormat.mBytesPerPacket   = sizeof(float);

    err = ExtAudioFileSetProperty(file,
                                  kExtAudioFileProperty_ClientDataFormat,
                                  sizeof(clientFormat),
                                  &clientFormat);
    if (err != noErr) {
        [self failWithMessage:NSLocalizedString(@"This audio format cannot be converted.", NULL)];
        goto cleanup;
    }

    SInt64 fileFrames = 0;
    size = sizeof(fileFrames);
    err = ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileLengthFrames, &size, &fileFrames);
    if (err != noErr || fileFrames <= 0) {
        [self failWithMessage:NSLocalizedString(@"Audio file is empty or unreadable.", NULL)];
        goto cleanup;
    }

    // After resampling, output frame count scales with the rate ratio. Round up
    // and add a small margin so ExtAudioFileRead can never overrun the buffer.
    double rateRatio = kImportTargetRate / fileFormat.mSampleRate;
    UInt64 estFrames = (UInt64)((double)fileFrames * rateRatio + 0.5) + kImportReadFrames;

    if (estFrames > (UInt64)UINT32_MAX / sizeof(float)) {
        [self failWithMessage:NSLocalizedString(@"Audio file is too long to import.", NULL)];
        goto cleanup;
    }

    size_t bufferBytes = (size_t)estFrames * sizeof(float);
    leftBuffer = (float *)malloc(bufferBytes);
    if (outChannels == 2) {
        rightBuffer = (float *)malloc(bufferBytes);
    }
    if (leftBuffer == NULL || (outChannels == 2 && rightBuffer == NULL)) {
        [self failWithMessage:NSLocalizedString(@"Unable to allocate memory for the converted sound.", NULL)];
        goto cleanup;
    }

    UInt64 framesRead = 0;
    UInt8  abListBacking[sizeof(AudioBufferList) + sizeof(AudioBuffer)];
    AudioBufferList *abList = (AudioBufferList *)abListBacking;

    while (framesRead < estFrames) {
        if (mCancelFlag) {
            [self performSelectorOnMainThread:@selector(finishWithAmplitude:)
                                   withObject:nil
                                waitUntilDone:NO];
            goto cleanup;
        }

        UInt32 framesToRead = kImportReadFrames;
        if (framesRead + framesToRead > estFrames)
            framesToRead = (UInt32)(estFrames - framesRead);

        abList->mNumberBuffers = outChannels;
        abList->mBuffers[0].mNumberChannels = 1;
        abList->mBuffers[0].mDataByteSize   = framesToRead * sizeof(float);
        abList->mBuffers[0].mData           = leftBuffer + framesRead;
        if (outChannels == 2) {
            abList->mBuffers[1].mNumberChannels = 1;
            abList->mBuffers[1].mDataByteSize   = framesToRead * sizeof(float);
            abList->mBuffers[1].mData           = rightBuffer + framesRead;
        }

        UInt32 frameCount = framesToRead;
        err = ExtAudioFileRead(file, &frameCount, abList);
        if (err != noErr) {
            [self failWithMessage:[NSString stringWithFormat:
                NSLocalizedString(@"Failed while reading audio data (error %d).", NULL), (int)err]];
            goto cleanup;
        }
        if (frameCount == 0)
            break;  // EOF

        framesRead += frameCount;

        // Throttle progress updates a bit; once per read is fine.
        float fraction = (float)((double)framesRead / (double)estFrames);
        if (fraction > 1.0f) fraction = 1.0f;
        [self performSelectorOnMainThread:@selector(updateProgress:)
                               withObject:[NSNumber numberWithFloat:fraction]
                            waitUntilDone:NO];
    }

    if (framesRead == 0) {
        [self failWithMessage:NSLocalizedString(@"Audio file produced no samples.", NULL)];
        goto cleanup;
    }

    // Apply the same scale convention as the AIFF importer:
    // sample * (fullScaleVoltage * 0.5).
    float scale = (float)([[AudioDialogPrefs shared] fullScaleVoltage] * 0.5);
    if (scale != 1.0f) {
        vDSP_vsmul(leftBuffer, 1, &scale, leftBuffer, 1, (vDSP_Length)framesRead);
        if (rightBuffer)
            vDSP_vsmul(rightBuffer, 1, &scale, rightBuffer, 1, (vDSP_Length)framesRead);
    }

    AudioDataAmplitude *amplitude = [[AudioDataAmplitude alloc] init];
    ULONG byteSize = (ULONG)(framesRead * sizeof(float));
    [amplitude setDataBuffer:leftBuffer  size:byteSize channel:LEFT_CHANNEL];
    if (rightBuffer)
        [amplitude setDataBuffer:rightBuffer size:byteSize channel:RIGHT_CHANNEL];

    // Ownership of the buffers transfers to AudioDataAmplitude.
    leftBuffer = NULL;
    rightBuffer = NULL;
    ok = YES;

    mAmplitude = amplitude;  // retained by caller via -finishWithAmplitude:
    [self performSelectorOnMainThread:@selector(finishWithAmplitude:)
                           withObject:amplitude
                        waitUntilDone:NO];

cleanup:
    if (file) ExtAudioFileDispose(file);
    if (!ok) {
        free(leftBuffer);
        free(rightBuffer);
    }
    [pool release];
}

#pragma mark - Main-thread completion

- (void)updateProgress:(NSNumber *)fraction
{
    [mProgressPanel setProgressValue:[fraction floatValue]];
}

- (void)finishWithAmplitude:(AudioDataAmplitude *)amplitude
{
    [mProgressPanel close];
    [mProgressPanel release];
    mProgressPanel = nil;

    [mDelegate performSelector:@selector(amplitudeFromAnyFileCompletedWithAmplitude:)
                    withObject:amplitude];
}

- (void)failWithMessage:(NSString *)message
{
    // Marshal onto the main thread so progress panel teardown and the alert
    // happen on the UI thread regardless of which thread invoked us.
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:_cmd withObject:message waitUntilDone:NO];
        return;
    }

    [mErrorMessage setString:message];
    [mProgressPanel close];
    [mProgressPanel release];
    mProgressPanel = nil;

    [mDelegate performSelector:@selector(amplitudeFromAnyFileCompletedWithAmplitude:)
                    withObject:nil];
}

@end
