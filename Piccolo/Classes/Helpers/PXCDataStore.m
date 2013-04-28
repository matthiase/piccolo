//
//  PXCDataStore.m
//  Piccolo
//
//  Created by Matthias Eder on 4/22/13.
//  Copyright (c) 2013 Matthias Eder. All rights reserved.
//

#import "PXCDataStore.h"
#import <AWSS3/AWSS3.h>


#define S3_REGION [S3Region USWest2]

@interface PXCDataStore ( )
{
    @private
    AmazonS3Client *s3;
    NSString *accessKey;
    NSString *secret;
    NSString *channelName;
    NSString *bucketName;
}
@end


@implementation PXCDataStore


static PXCDataStore *_sharedClient = nil;

+(PXCDataStore *)sharedClient
{
    static dispatch_once_t once;    
    dispatch_once(&once, ^{
        _sharedClient = [[[self class] alloc] init];
    });
    return _sharedClient;
}


+(void)reconnect
{
    NSLog(@"Reconnecting to datastore.");
    _sharedClient = [[[self class] alloc] init];
}


-(id)init
{
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


-(void)createBucket:(void (^)(NSError *))block
{
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


-(void)listObjects:(void (^)(NSArray *, NSError *))block
{
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


-(void)getObject:(NSString *)key withBlock:(void (^)(NSData *, NSError *))block
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


-(void)writeObject:(NSData *)data ofType:(NSString *)objectType WithKey:(NSString *)key andBlock:(void (^)(NSError *))block
{
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
                
       // If a delegate is set, the requests will not block, and the delegate must handle the response in the
       // request:didCompleteWithResponse: method.
        S3PutObjectRequest *request = [[S3PutObjectRequest alloc] initWithKey:key inBucket:bucketName];
        //[request setDelegate:<#(id<AmazonServiceRequestDelegate>)#>];
        request.contentType = objectType;
        request.data = data;
        
        S3PutObjectResponse *response = [s3 putObject:request];        
        // TODO: does this marshal back to the main thread?
        dispatch_async(dispatch_get_main_queue(), ^{
            block(response.error);
        });
        
    });
}

@end
