//
//  RKResponseSerialization.m
//  RestKit
//
//  Created by Blake Watters on 11/16/13.
//  Copyright (c) 2013 RestKit. All rights reserved.
//

#import "RKResponseSerialization.h"
#import "RKResponseMapperOperation.h"

@interface RKResponseSerializationManager ()
@property (nonatomic, strong, readwrite) AFHTTPResponseSerializer *dataSerializer;
@property (nonatomic, strong) NSMutableArray *mutableResponseDescriptors;
@end

@implementation RKResponseSerializationManager

+ (instancetype)managerWithDataSerializer:(AFHTTPResponseSerializer *)dataSerializer
{
    if (!dataSerializer) [NSException raise:NSInvalidArgumentException format:@"`%@` cannot be `nil`.", NSStringFromSelector(@selector(dataSerializer))];
    return [[self alloc] initWithDataSerializer:dataSerializer];
}

- (id)initWithDataSerializer:(AFHTTPResponseSerializer *)dataSerializer
{
    self = [super init];
    if (self) {
        self.dataSerializer = dataSerializer;
        self.mutableResponseDescriptors = [NSMutableArray new];
    }
    return self;
}

- (id)init
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"Failed to call designated initializer. Call `%@` instead", NSStringFromSelector(@selector(managerWithDataSerializer:))]
                                 userInfo:nil];
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [self init];
    if (!self) {
        return nil;
    }

    [self addResponseDescriptors:[decoder decodeObjectForKey:NSStringFromSelector(@selector(responseDescriptors))]];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.responseDescriptors forKey:NSStringFromSelector(@selector(responseDescriptors))];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    RKResponseSerializationManager *serializer = (RKResponseSerializationManager *)[[self class] new];
    [serializer addResponseDescriptors:self.responseDescriptors];
    return serializer;
}

- (NSArray *)responseDescriptors
{
    return [NSArray arrayWithArray:self.mutableResponseDescriptors];
}

- (void)addResponseDescriptor:(RKResponseDescriptor *)responseDescriptor
{
    NSParameterAssert(responseDescriptor);
    NSAssert([responseDescriptor isKindOfClass:[RKResponseDescriptor class]], @"Expected an object of type RKResponseDescriptor, got '%@'", [responseDescriptor class]);
    [self.mutableResponseDescriptors addObject:responseDescriptor];
}

- (void)addResponseDescriptors:(NSArray *)responseDescriptors
{
    for (RKResponseDescriptor *responseDescriptor in responseDescriptors) {
        [self addResponseDescriptor:responseDescriptor];
    }
}

- (void)removeResponseDescriptor:(RKResponseDescriptor *)responseDescriptor
{
    NSParameterAssert(responseDescriptor);
    NSAssert([responseDescriptor isKindOfClass:[RKResponseDescriptor class]], @"Expected an object of type RKResponseDescriptor, got '%@'", [responseDescriptor class]);
    [self.mutableResponseDescriptors removeObject:responseDescriptor];
}

// TODO: Migrate functionality of `appropriateObjectRequestOperation...`
- (RKObjectResponseSerializer *)serializerWithRequest:(NSURLRequest *)request object:(id)object
{
    AFHTTPResponseSerializer *dataSerializer = [self.dataSerializer copy];
    dataSerializer.acceptableStatusCodes = nil; // TODO: Configure the acceptable status codes to exactly match those of the response descriptors.
    RKObjectResponseSerializer *responseSerializer = [[RKObjectResponseSerializer alloc] initWithRequest:request dataSerializer:dataSerializer responseDescriptors:self.responseDescriptors];
    responseSerializer.targetObject = object;
    return responseSerializer;
}

@end

@interface RKObjectResponseSerializer ()
@property (nonatomic, strong, readwrite) NSURLRequest *request;
@property (nonatomic, strong, readwrite) AFHTTPResponseSerializer *dataSerializer;
@property (nonatomic, copy, readwrite) NSArray *responseDescriptors;
@end

@implementation RKObjectResponseSerializer

- (id)init
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"Failure to call designated initializer: call `%@` instead", NSStringFromSelector(@selector(initWithRequest:dataSerializer:responseDescriptors:))]
                                 userInfo:nil];
}

- (id)initWithRequest:(NSURLRequest *)request dataSerializer:(AFHTTPResponseSerializer *)dataSerializer responseDescriptors:(NSArray *)responseDescriptors
{
    self = [super init];
    if (self) {
        self.request = request;
        self.dataSerializer = dataSerializer;
        self.responseDescriptors = responseDescriptors;
    }
    return self;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"To be implemented..." userInfo:nil];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"To be implemented..." userInfo:nil];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"To be implemented..." userInfo:nil];
}

#pragma mark -

- (id)responseObjectForResponse:(NSURLResponse *)response
                           data:(NSData *)data
                          error:(NSError *__autoreleasing *)error
{
    if (![self.dataSerializer validateResponse:(NSHTTPURLResponse *)response data:data error:error]) {
        if ([(NSError *)(*error) code] == NSURLErrorCannotDecodeContentData) {
            return nil;
        }
    }

    id responseObject = [self.dataSerializer responseObjectForResponse:response data:data error:error];
    if (!responseObject) return nil;

    RKObjectResponseMapperOperation *mapperOperation = [[RKObjectResponseMapperOperation alloc] initWithRequest:self.request response:(NSHTTPURLResponse *)response representation:responseObject responseDescriptors:self.responseDescriptors];
    mapperOperation.targetObject = self.targetObject;
    [mapperOperation start];
    if (mapperOperation.error) {
        *error = mapperOperation.error;
        return nil;
    }
    return mapperOperation.mappingResult;
}

@end

@implementation RKManagedObjectResponseSerializer
@end
