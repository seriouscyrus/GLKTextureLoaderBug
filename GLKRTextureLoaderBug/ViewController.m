//
//  ViewController.m
//  GLKRTextureLoaderBug
//
//  Created by George Brown on 05/02/16.
//  Copyright © 2016 Serious Cyrus. All rights reserved.
//

#import "ViewController.h"
#import <Photos/Photos.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    // Grab the first photo
    _needsRebuild = YES;
    _needsNewTexture = NO;
    
    [self addObserver:self forKeyPath:@"image" options:NSKeyValueObservingOptionNew context:nil];
    [self addObserver:self forKeyPath:@"GLKView.bounds" options:NSKeyValueObservingOptionNew context:nil];
    
    self.GLKView.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [self setuOpenGL];
    [self aquireImage];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) aquireImage
{
    if ([PHPhotoLibrary authorizationStatus] != PHAuthorizationStatusAuthorized) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            if (status != PHAuthorizationStatusAuthorized) {
                NSLog(@"No authorization!");
            } else {
                // Try this method again, but call on main thread as this block returns on a seperate thread
                [self performSelectorOnMainThread:@selector(aquireImage) withObject:self waitUntilDone:NO];
                //[self aquireImage];
            }
        }];
    } else {
        PHFetchResult *smartAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum
                                                                              subtype:PHAssetCollectionSubtypeAlbumRegular
                                                                              options:nil];
        
        self.image = [self getFirstPhotoFromFetchResult:smartAlbums];
        if (!self.image) {
            PHFetchResult *albums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAny options:nil];
            self.image = [self getFirstPhotoFromFetchResult:albums];
        }
    }
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if (object == self && [keyPath isEqualToString:@"image"]) {
        if (self.image) {
            self.imageView.image = self.image;
            _needsNewTexture = YES;
            [self.GLKView setNeedsDisplay];
        }
    } else if (object == self.GLKView && [keyPath isEqualToString:@"bounds"]) {
        _needsRebuild = YES;
    }
}

- (UIImage *) getFirstPhotoFromFetchResult:(PHFetchResult *) result
{
    __block UIImage *image;
    for (PHAssetCollection *collection in result) {
        // Get the assest
        PHFetchOptions *options = [PHFetchOptions new];
        options.predicate = [NSPredicate predicateWithFormat:@"mediaType == %i", PHAssetMediaTypeImage];
        PHFetchResult *assetResult = [PHAsset fetchAssetsInAssetCollection:collection options:options];
        if (assetResult.count) {
            PHAsset *firstAsset = assetResult.firstObject;
            PHImageRequestOptions *imgOptions = [[PHImageRequestOptions alloc] init];
            imgOptions.resizeMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
            
            // Make it synchronous, we're not bothered about speed and it complicates things
            imgOptions.synchronous = YES;
            
            CGFloat scale = [UIScreen mainScreen].scale;
            CGSize size = CGSizeMake(self.imageView.bounds.size.width*scale, self.imageView.bounds.size.height*scale);
            PHImageManager *im = [PHImageManager defaultManager];
            [im requestImageForAsset:firstAsset
                          targetSize:size
                         contentMode:PHImageContentModeAspectFill
                             options:imgOptions
                       resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info)
             {
                 image = result;
             }];
            break;
        }
        
    }
    return image;
}

- (void) glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    if (_needsRebuild) {
        [self genVAO];
        _baseEffect.transform.projectionMatrix = _mvpMatrix;
        [_baseEffect prepareToDraw];
    }
    if (_needsNewTexture) {
        // Delete any existing
        if (_texture) {
            glDeleteTextures(1, &_texture);
            _texture = 0;
        }
        // get the texture, just go synchronously, we're not bothered with speed here
        NSError *error;
        GLKTextureInfo *tex = [GLKTextureLoader textureWithCGImage:_image.CGImage options:nil error:&error];
        if (!error) {
            if (tex) {
                _texture = tex.name;
                _baseEffect.texture2d0.name = _texture;
                _baseEffect.texture2d0.target = tex.target;
                [_baseEffect prepareToDraw];
                _needsNewTexture = NO;
            } else {
                NSLog(@"No texture, no error");
            }
        } else {
            NSLog(@"Error loading texture : %@", error);
            GLenum glerror = glGetError();
            if (glerror != GL_NO_ERROR) {
                NSString *returnValue;
                switch (glerror) {
                    case GL_INVALID_ENUM:
                        returnValue = @"GL_INVALID_ENUM";
                        break;
                    case GL_INVALID_VALUE:
                        returnValue = @"GL_INVALID_VALUE";
                        break;
                    case GL_INVALID_OPERATION:
                        returnValue = @"GL_INVALID_OPERATION";
                        break;
                    case GL_INVALID_FRAMEBUFFER_OPERATION:
                        returnValue = @"GL_INVALID_FRAMEBUFFER_OPERATION";
                        break;
                    default:
                        returnValue = [NSString stringWithFormat:@"Not found : %i", glerror];
                        break;
                }
                NSLog(@"Error = %@", returnValue);
            }
        }
    }
    
    glClearColor(1.0, 1.0, 1.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    glBindVertexArray(_vertexArrayObject);
    glDrawElements(GL_TRIANGLE_STRIP, 4, GL_UNSIGNED_SHORT, 0);
    glBindVertexArray(0);
    
}

- (void) genMVPMatrix
{
    _mvpMatrix = GLKMatrix4Multiply(
                                    GLKMatrix4MakeOrtho(
                                                        0.0,
                                                        self.GLKView.frame.size.width,
                                                        self.GLKView.frame.size.height,
                                                        0.0,
                                                        0.0,
                                                        1.0),
                                    GLKMatrix4Identity
                                    );
}

- (void) setuOpenGL
{
    // Disable stuff we don't need
    [EAGLContext setCurrentContext:self.GLKView.context];
    _baseEffect = [[GLKBaseEffect alloc] init];
    glDisable(GL_DEPTH_TEST);
}

- (void) genIndexBuffer
{
    if (_indexBufferName) {
        glDeleteBuffers(1, &_indexBufferName);
        _indexBufferName = 0;
    }
    GLushort indices[] = {0, 1, 2, 3};
    glGenBuffers(1, &_indexBufferName);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBufferName);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_DYNAMIC_DRAW);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
}

- (void) genColoursBuffer
{
    if (_colourBufferName) {
        glDeleteBuffers(1, &_colourBufferName);
        _colourBufferName = 0;
    }
    //Create colours
    GLfloat colours[16];
    for (int i = 0; i < 16; i++) {
        colours[i] = 1.0;
    }
    glGenBuffers(1, &_colourBufferName);
    glBindBuffer(GL_ARRAY_BUFFER, _colourBufferName);
    glBufferData(GL_ARRAY_BUFFER, sizeof(colours), colours, GL_DYNAMIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
}

- (void) genVertCoordsBuffer
{
    if (_vertCoordsBufferName) {
        glDeleteBuffers(1, &_vertCoordsBufferName);
        _vertCoordsBufferName = 0;
    }
    GLfloat aspectVid = self.image.size.width/self.image.size.height;
    GLfloat aspectView = self.GLKView.frame.size.width/self.GLKView.frame.size.height;
    GLfloat minx = 0.0, miny = 0.0, maxx = self.GLKView.frame.size.width, maxy = self.GLKView.frame.size.height;
    if (aspectVid > aspectView) {
        GLfloat dif = self.GLKView.frame.size.height - (self.GLKView.frame.size.width/aspectVid);
        miny = dif/2;
        maxy -= dif/2;
    } else if (aspectVid < aspectView) {
        GLfloat dif = self.GLKView.frame.size.width - (self.GLKView.frame.size.height*aspectVid);
        minx = dif/2;
        maxx -= dif/2;
    }
    
    GLfloat coords[] = {
        minx, miny, 0.0, 1.0,
        maxx, miny, 0.0, 1.0,
        minx, maxy, 0.0, 1.0,
        maxx, maxy, 0.0, 1.0,
    };
    glGenBuffers(1, &_vertCoordsBufferName);
    glBindBuffer(GL_ARRAY_BUFFER, _vertCoordsBufferName);
    glBufferData(GL_ARRAY_BUFFER, sizeof(coords), coords, GL_DYNAMIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
}

- (void) genTexCoordsBuffer
{
    // Normalized for iOS GL_TEXTURE_2D
    if (_texCoordsBufferName) {
        glDeleteBuffers(1, &_texCoordsBufferName);
        _texCoordsBufferName = 0;
    }
    
    GLfloat coords[] = {
        0.0, 0.0, 0.0, 1.0,
        1.0, 0.0, 0.0, 1.0,
        0.0, 1.0, 0.0, 1.0,
        1.0, 1.0, 0.0, 1.0,
    };
    glGenBuffers(1, &_texCoordsBufferName);
    glBindBuffer(GL_ARRAY_BUFFER, _texCoordsBufferName);
    glBufferData(GL_ARRAY_BUFFER, sizeof(coords), coords, GL_DYNAMIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
}

- (void) genVAO
{
    // Generate the VAO and anything else that might be affected by any kind of view change
    [self genMVPMatrix];
    [self genVertCoordsBuffer];
    [self genTexCoordsBuffer];
    [self genColoursBuffer];
    [self genIndexBuffer];
    
    if (_vertexArrayObject) {
        glDeleteVertexArrays(1, &_vertexArrayObject);
        _vertexArrayObject = 0;
    }
    glGenVertexArrays(1, &_vertexArrayObject);
    glBindVertexArray(_vertexArrayObject);
    
    glBindBuffer(GL_ARRAY_BUFFER, self.vertCoordsBufferName);
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 4, GL_FLOAT, GL_FALSE, 0, 0);
    
    glBindBuffer(GL_ARRAY_BUFFER, self.texCoordsBufferName);
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 4, GL_FLOAT, GL_FALSE, 0, 0);
    
    glBindBuffer(GL_ARRAY_BUFFER, self.colourBufferName);
    glEnableVertexAttribArray(GLKVertexAttribColor);
    glVertexAttribPointer(GLKVertexAttribColor, 4, GL_FLOAT, GL_FALSE, 0, 0);
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, self.indexBufferName);
    
    // Unbind
    glBindVertexArray(0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    // Disable
    glDisableVertexAttribArray(GLKVertexAttribPosition);
    glDisableVertexAttribArray(GLKVertexAttribTexCoord0);
    glDisableVertexAttribArray(GLKVertexAttribColor);
    _needsRebuild = NO;
}

- (void) destroyCGLResources
{
    [EAGLContext setCurrentContext:self.GLKView.context];
    if (_vertexArrayObject) {
        glDeleteVertexArrays(1, &_vertexArrayObject);
        _vertexArrayObject = 0;
    }
    if (_indexBufferName) {
        glDeleteBuffers(1, &_indexBufferName);
        _indexBufferName = 0;
    }
    if (_vertCoordsBufferName) {
        glDeleteBuffers(1, &_vertCoordsBufferName);
        _vertCoordsBufferName = 0;
    }
    if (_texCoordsBufferName) {
        glDeleteBuffers(1, &_texCoordsBufferName);
        _texCoordsBufferName = 0;
    }
    if (_colourBufferName) {
        glDeleteBuffers(1, &_colourBufferName);
        _colourBufferName = 0;
    }
    _baseEffect = nil;
    _needsRebuild = YES;
}



@end
