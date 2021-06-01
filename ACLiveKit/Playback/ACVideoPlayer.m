//
//  ACVideoPlayer.m
//  ACLivePlayer
//
//  Created by beichen on 2021/5/15.
//

#import "ACVideoPlayer.h"
#import "LYShaderTypes.h"
#import <MetalKit/MetalKit.h>
#import <GLKit/GLKit.h>
#import "ACVideoYuvFrame.h"

@interface ACVideoPlayer () <MTKViewDelegate>

// view
@property (nonatomic, strong) MTKView *mtkView;

// reader
@property (nonatomic) dispatch_semaphore_t lock;
@property (nonatomic, strong) NSMutableArray *frameBuffer;
@property (nonatomic, assign) CVMetalTextureCacheRef textureCache;

// data
@property (nonatomic, assign) vector_uint2 viewportSize;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLTexture> texture;
@property (nonatomic, strong) id<MTLBuffer> vertices;
@property (nonatomic, strong) id<MTLBuffer> convertMatrix;
@property (nonatomic, assign) NSUInteger numVertices;

@end

@implementation ACVideoPlayer

/// 初始化
/// @param playView 播放容器
- (instancetype)initWithView:(UIView *)playView {
    if (self = [super init]) {
        _frameBuffer = [NSMutableArray array];
        _lock = dispatch_semaphore_create(1);
        [self setupPlayView:playView];
        [self setupPipeline];
        [self setupVertex];
        [self setupMatrix];
    }
    return self;
}

// 初始化播放页
- (void)setupPlayView:(UIView *)playView {
    self.mtkView = [[MTKView alloc] initWithFrame:playView.bounds];
    self.mtkView.device = MTLCreateSystemDefaultDevice(); // 获取默认的device
    self.mtkView.delegate = self;
    [playView insertSubview:self.mtkView atIndex:0];
    
    self.viewportSize = (vector_uint2){self.mtkView.drawableSize.width, self.mtkView.drawableSize.height};
    
    // 创建纹理缓存：TextureCache
    CVMetalTextureCacheCreate(NULL, NULL, self.mtkView.device, NULL, &_textureCache);
}

/**
 
 // BT.601, which is the standard for SDTV.
 matrix_float3x3 kColorConversion601Default = (matrix_float3x3){
 (simd_float3){1.164,  1.164, 1.164},
 (simd_float3){0.0, -0.392, 2.017},
 (simd_float3){1.596, -0.813,   0.0},
 };
 
 //// BT.601 full range (ref: http://www.equasys.de/colorconversion.html)
 matrix_float3x3 kColorConversion601FullRangeDefault = (matrix_float3x3){
 (simd_float3){1.0,    1.0,    1.0},
 (simd_float3){0.0,    -0.343, 1.765},
 (simd_float3){1.4,    -0.711, 0.0},
 };
 
 //// BT.709, which is the standard for HDTV.
 matrix_float3x3 kColorConversion709Default[] = {
 (simd_float3){1.164,  1.164, 1.164},
 (simd_float3){0.0, -0.213, 2.112},
 (simd_float3){1.793, -0.533,   0.0},
 };
 */
- (void)setupMatrix {
    // 设置好转换的矩阵
    matrix_float3x3 kColorConversion601FullRangeMatrix = (matrix_float3x3){
        (simd_float3){1.0,    1.0,    1.0},
        (simd_float3){0.0,    -0.343, 1.765},
        (simd_float3){1.4,    -0.711, 0.0},
    };
    
    // 设置偏移
    vector_float3 kColorConversion601FullRangeOffset = (vector_float3){ -(16.0/255.0), -0.5, -0.5};
    
    // 设置参数
    LYConvertMatrix matrix;
    matrix.matrix = kColorConversion601FullRangeMatrix;
    matrix.offset = kColorConversion601FullRangeOffset;
    
    self.convertMatrix = [self.mtkView.device newBufferWithBytes:&matrix
                                                          length:sizeof(LYConvertMatrix)
                                                         options:MTLResourceStorageModeShared];
}

// 设置渲染管道
-(void)setupPipeline {
    // shaders.metal
    id<MTLLibrary> defaultLibrary = [self.mtkView.device newDefaultLibrary];
    
    // 顶点shader：vertexShader是函数名
    id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
    
    // 片元shader：samplingShader是函数名
    id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"samplingShader"];
    
    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.vertexFunction = vertexFunction;
    pipelineStateDescriptor.fragmentFunction = fragmentFunction;
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = self.mtkView.colorPixelFormat; // 设置颜色格式
    
    // 创建图形渲染管道，耗性能操作不宜频繁调用
    self.pipelineState = [self.mtkView.device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                                             error:NULL];
    
    // CommandQueue是渲染指令队列，保证渲染指令有序地提交到GPU
    self.commandQueue = [self.mtkView.device newCommandQueue];
}

// 设置顶点
- (void)setupVertex {
    static const LYVertex quadVertices[] =
    {   // 顶点坐标，分别是x、y、z、w；    纹理坐标，x、y；
        { {  1.0, -1.0, 0.0, 1.0 },  { 1.f, 1.f } },
        { { -1.0, -1.0, 0.0, 1.0 },  { 0.f, 1.f } },
        { { -1.0,  1.0, 0.0, 1.0 },  { 0.f, 0.f } },
        
        { {  1.0, -1.0, 0.0, 1.0 },  { 1.f, 1.f } },
        { { -1.0,  1.0, 0.0, 1.0 },  { 0.f, 0.f } },
        { {  1.0,  1.0, 0.0, 1.0 },  { 1.f, 0.f } },
    };
    
    // 创建顶点缓存
    self.vertices = [self.mtkView.device newBufferWithBytes:quadVertices
                                                     length:sizeof(quadVertices)
                                                    options:MTLResourceStorageModeShared];
    self.numVertices = sizeof(quadVertices) / sizeof(LYVertex); // 顶点个数
}

// 设置纹理
- (void)setupTextureWithEncoder:(id<MTLRenderCommandEncoder>)encoder buffer:(CVPixelBufferRef)pixelBuffer {
    id<MTLTexture> textureY = nil;
    id<MTLTexture> textureUV = nil;
    
    // textureY 设置
    {
        size_t width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
        size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
        MTLPixelFormat pixelFormat = MTLPixelFormatR8Unorm; // 这里的颜色格式不是RGBA

        CVMetalTextureRef texture = NULL; // CoreVideo的Metal纹理
        CVReturn status = CVMetalTextureCacheCreateTextureFromImage(NULL, self.textureCache, pixelBuffer, NULL, pixelFormat, width, height, 0, &texture);
        if(status == kCVReturnSuccess)
        {
            textureY = CVMetalTextureGetTexture(texture); // 转成Metal用的纹理
            CFRelease(texture);
        }
    }
    
    // textureUV 设置
    {
        size_t width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1);
        size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
        MTLPixelFormat pixelFormat = MTLPixelFormatRG8Unorm; // 2-8bit的格式
        
        CVMetalTextureRef texture = NULL; // CoreVideo的Metal纹理
        CVReturn status = CVMetalTextureCacheCreateTextureFromImage(NULL, self.textureCache, pixelBuffer, NULL, pixelFormat, width, height, 1, &texture);
        if(status == kCVReturnSuccess)
        {
            textureUV = CVMetalTextureGetTexture(texture); // 转成Metal用的纹理
            CFRelease(texture);
        }
    }
    
    if(textureY != nil && textureUV != nil)
    {
        [encoder setFragmentTexture:textureY
                            atIndex:LYFragmentTextureIndexTextureY]; // 设置纹理
        [encoder setFragmentTexture:textureUV
                            atIndex:LYFragmentTextureIndexTextureUV]; // 设置纹理
    }
    CFRelease(pixelBuffer); // 记得释放
}


#pragma mark - MTKViewDelegate

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    self.viewportSize = (vector_uint2){size.width, size.height};
}

- (void)drawInMTKView:(MTKView *)view {
    // 每次渲染都要单独创建一个CommandBuffer
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    // MTLRenderPassDescriptor描述一系列attachments的值，类似GL的FrameBuffer；同时也用来创建MTLRenderCommandEncoder
    CVPixelBufferRef pixelBuffer = [self readPixelBuffer]; // 从缓存中读取图像数据
    if(renderPassDescriptor && pixelBuffer)
    {
        // 设置默认颜色
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.5, 0.5, 1.0f);
        
        // 编码绘制指令的Encoder
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        
        // 设置显示区域
        [renderEncoder setViewport:(MTLViewport){0.0, 0.0, self.viewportSize.x, self.viewportSize.y, -1.0, 1.0 }];
        
        // 设置渲染管道，以保证顶点和片元两个shader会被调用
        [renderEncoder setRenderPipelineState:self.pipelineState];
        
        // 设置顶点缓存
        [renderEncoder setVertexBuffer:self.vertices
                                offset:0
                               atIndex:LYVertexInputIndexVertices];
        
        [self setupTextureWithEncoder:renderEncoder buffer:pixelBuffer];
        [renderEncoder setFragmentBuffer:self.convertMatrix
                                  offset:0
                                 atIndex:LYFragmentInputIndexMatrix];
        
        // 绘制
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                          vertexStart:0
                          vertexCount:self.numVertices];
        
        // 结束
        [renderEncoder endEncoding];
        
        // 显示
        [commandBuffer presentDrawable:view.currentDrawable];
    }
    
    [commandBuffer commit]; // 提交
}

#pragma mark - Display

/// 渲染YUV图像
/// @param yuvFrame YUV数据
- (void)displayYuvFrame:(ACVideoYuvFrame*)yuvFrame {
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    [self.frameBuffer addObject:yuvFrame];
    dispatch_semaphore_signal(_lock);
}

// 读取YUV数据
- (CVPixelBufferRef)readPixelBuffer {
    CVPixelBufferRef pixelBuffer = NULL;
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    ACVideoYuvFrame *frame = [self.frameBuffer firstObject];
    if (frame) {
        pixelBuffer = frame.pixelBuffer;
        [self.frameBuffer removeObjectAtIndex:0];
    }
    dispatch_semaphore_signal(_lock);
    return pixelBuffer;
}

@end
