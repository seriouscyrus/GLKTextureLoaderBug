//
//  ViewController.h
//  GLKRTextureLoaderBug
//
//  Created by George Brown on 05/02/16.
//  Copyright © 2016 Serious Cyrus. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>

@interface ViewController : UIViewController <GLKViewDelegate>;

@property (nonatomic)               UIImage         *image;

//GL Stuff
@property (nonatomic, readonly)     GLuint          texture;
@property (nonatomic, readonly)     GLuint          vertexArrayObject;
@property (nonatomic, readonly)     GLuint          indexBufferName;
@property (nonatomic, readonly)     GLuint          vertCoordsBufferName;
@property (nonatomic, readonly)     GLuint          texCoordsBufferName;
@property (nonatomic, readonly)     GLuint          colourBufferName;
@property (nonatomic, readonly)     GLKMatrix4      mvpMatrix;
@property (nonatomic, readonly)     GLKBaseEffect   *baseEffect;
@property (nonatomic, readonly)     BOOL            needsRebuild;
@property (nonatomic, readonly)     BOOL            needsNewTexture;

@property (weak, nonatomic) IBOutlet UIImageView    *imageView;
@property (weak, nonatomic) IBOutlet GLKView        *GLKView;

@end

