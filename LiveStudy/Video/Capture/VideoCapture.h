//
//  VideoCapture.h
//  LiveStudy
//
//  Created by wenba201600164 on 16/7/13.
//  Copyright © 2016年 wenba. All rights reserved.
//

/*
 * 参考 https://objccn.io/issue-23-1/
 */

#import <Foundation/Foundation.h>
#import <UIKIt/UIKit.h>

@import AVFoundation;


@interface VideoCapture : NSObject

- (void)setPreview:(UIView *)preview;
- (void)start;
- (void)stop;

- (void)startWithPreView:(UIView *)view;

@end
