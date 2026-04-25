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

#import "ARDynamicMenu.h"

// The Carbon menu-event hooks this class used (InstallMenuEventHandler,
// InvalidateMenuItems, UpdateInvalidMenuItems, _NSGetCarbonMenu) are not
// available in modern macOS. The class is retained as a no-op so callers
// compile and run; dynamic modifier-key menu relabeling is simply disabled.

@implementation ARDynamicMenu

+ (ARDynamicMenu*)shared
{
    static ARDynamicMenu *_ARDynamicMenu = NULL;
    if(_ARDynamicMenu == NULL)
        _ARDynamicMenu = [[ARDynamicMenu alloc] init];
    return _ARDynamicMenu;
}

- (id)init
{
    if(self = [super init])
    {
        mItemDelegateArray = [[NSMutableArray alloc] init];
        mMenuCallbackArray = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [mMenuCallbackArray release];
    [mItemDelegateArray release];
    [super dealloc];
}

- (BOOL)addDynamicMenuItem:(NSMenuItem*)item delegate:(id)delegate
{
    [mItemDelegateArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:item, @"Item", delegate, @"Delegate", NULL]];
    return YES;
}

- (void)removeDynamicMenuItem:(NSMenuItem*)item
{
    NSEnumerator *enumerator = [mItemDelegateArray reverseObjectEnumerator];
    NSDictionary *dic = nil;
    while(dic = [enumerator nextObject]) {
        if([dic objectForKey:@"Item"] == item)
            [mItemDelegateArray removeObject:dic];
    }
}

- (void)removeDynamicMenuDelegate:(id)delegate
{
    NSEnumerator *enumerator = [mItemDelegateArray reverseObjectEnumerator];
    NSDictionary *dic = nil;
    while(dic = [enumerator nextObject]) {
        if([dic objectForKey:@"Delegate"] == delegate)
            [mItemDelegateArray removeObject:dic];
    }
}

- (void)notifyDelegateWithModifiers:(UInt32)modifiers
{
    // No-op: modifier-key notifications required Carbon event hooks.
}

@end
