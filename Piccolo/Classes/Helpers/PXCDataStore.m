//
// PXCDataStore.m
//
// Copyright (c) 2013 Matthias Eder
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "PXCDataStore.h"
#import <AWSS3/AWSS3.h>


// Using a hardcoded AWS region for now.  In the future, this should probably be
// made configurable.
#define S3_REGION [S3Region USWest2]

@interface PXCDataStore ( )
{
    @private
    AmazonS3Client *s3;     // the Amazon S3 client
    NSString *accessKey;    // AWS access key
    NSString *secret;       // AWS secret
    NSString *channelName;  // name of the subscribed channel
    NSString *bucketName;   // S3 bucket name, which is a combination of channelName
                            // and access key
}
@end


@implementation PXCDataStore

static PXCDataStore *_sharedClient = nil;

+(PXCDataStore *)sharedClient {
    static dispatch_once_t once;    
    dispatch_once(&once, ^{
        _sharedClient = [[[self class] alloc] init];
    });
    return _sharedClient;
}


+(void)reconnect {
    _sharedClient = [[[self class] alloc] init];
}


// Initializes the shared instance with the AWS properties stored in the standard user
// preferences and the AWS availablity zone specified in the header file.
-(id)init {
    self = [super init];
    if (self) {        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        accessKey = [defaults objectForKey:@"aws_access_key"];
        secret = [defaults objectForKey:@"aws_secret"];
        channelName = [defaults objectForKey:@"channel_name"];
        bucketName = [[NSString stringWithFormat:@"%@-%@", channelName, accessKey] lowercaseString];
        
        s3 = [[AmazonS3Client alloc] initWithAccessKey:accessKey withSecretKey:secret];
        s3.endpoint = [AmazonEndpoints s3Endpoint:US_WEST_2];        
    }
    return self;
}


-(void)createBucket:(void (^)(NSError *))block {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        NSError *error;
        @try {
            S3CreateBucketRequest *req = [[S3CreateBucketRequest alloc] initWithName:bucketName andRegion:S3_REGION];
            S3CreateBucketResponse *resp = [s3 createBucket:req];
            error = resp.error;
        }
        @catch (AmazonServiceException *ex) {
            NSLog(@"[PXCDataStore::init] %@", ex.message);            
            NSDictionary * details = @{ NSLocalizedFailureReasonErrorKey:ex.errorCode, NSLocalizedDescriptionKey:ex.message };
            error = [NSError errorWithDomain:@"PXCDataStore" code:ex.statusCode userInfo:details];
        }
        @catch (NSException *ex) {
            NSLog(@"[PXCDataStore::init]: %@", ex.reason);
            NSDictionary * details = @{ NSLocalizedDescriptionKey:ex.reason };
            error = [NSError errorWithDomain:@"PXCDataStore" code:1000 userInfo:details];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            block(error);
        });
        
    });
}


-(void)listObjects:(void (^)(NSArray *, NSError *))block {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        NSMutableArray *results = nil;
        S3ListObjectsRequest *req = [[S3ListObjectsRequest alloc] initWithName:bucketName];
        req.marker = nil;
        req.maxKeys = 20;

        NSError *error = nil;
        S3ListObjectsResponse *resp = nil;
        
        @try {
            resp = [s3 listObjects:req];
            error = resp.error;
        }
        @catch (AmazonServiceException *ex) {
            NSLog(@"PXCDataStore::listObjects] %@", ex.message);
            error = [NSError errorWithDomain:@"PXCDataStore" code:200 userInfo:@{NSLocalizedDescriptionKey: ex.message}];
        }
        @catch (NSException *ex) {
            NSLog(@"PXCDataStore::listObjects] %@", ex.reason);
            error = [NSError errorWithDomain:@"PXCDataStore" code:200 userInfo:@{NSLocalizedDescriptionKey: ex.reason}];
        }
        
        if (!error) {
            results = [[NSMutableArray alloc] initWithCapacity:[resp.listObjectsResult.objectSummaries count]];
            for (int i = 0; i < [resp.listObjectsResult.objectSummaries count]; i++) {
                results[i] = [resp.listObjectsResult.objectSummaries[i] key];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            block( [NSArray arrayWithArray:results], error);
        });
    });
}


-(void)getObject:(NSString *)key
       withBlock:(void (^)(NSData *, NSError *))block
{
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{        
        NSData *data = nil;
        S3GetObjectRequest *req = [[S3GetObjectRequest alloc] initWithKey:key withBucket:bucketName];
        S3GetObjectResponse *resp = [s3 getObject:req];
        
        if (!resp.error) {
            data = resp.body;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            block(data, resp.error);
        });
    });
}


-(void)writeObject:(NSData *)data
            ofType:(NSString *)objectType
           WithKey:(NSString *)key
          andBlock:(void (^)(NSError *))block
{
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        S3PutObjectRequest *request = [[S3PutObjectRequest alloc] initWithKey:key inBucket:bucketName];
        request.contentType = objectType;
        request.data = data;
        
        S3PutObjectResponse *response = [s3 putObject:request];
        dispatch_async(dispatch_get_main_queue(), ^{
            block(response.error);
        });        
    });
}

@end
