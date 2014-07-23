//
//  OTGNetworkRequest.m
//  On The Go
//
//  Created by Eric Gao on 7/3/14.
//  Copyright (c) 2014 Eric Gao. All rights reserved.
//

#import "OTGNetworkRequest.h"
#import "OTGNetworkConstants.h"
#import "AFHTTPRequestOperation.h"
#import <CoreLocation/CoreLocation.h>

@implementation OTGNetworkRequest

+ (void)fetchPotentialPlacesWithString:(NSString *) searchString withLocation:(CLLocation *)currentLocation success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success {
    searchString = [searchString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *requestURLString = [NSString stringWithFormat:@"%@input=%@&radius=5000&location=%f,%f&key=%@", BASE_AUTOCOMPLETE_URL, searchString, currentLocation.coordinate.latitude, currentLocation.coordinate.longitude, SERVER_API_KEY];
    NSURL *requestURL = [NSURL URLWithString:requestURLString];
    NSURLRequest *request = [NSURLRequest requestWithURL:requestURL];
    
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    operation.responseSerializer = [AFJSONResponseSerializer serializer];
    
    [operation setCompletionBlockWithSuccess:success failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"%@", error);
    }];
    
    [operation start];
}

+ (void)fetchPlaceDetailsWithReference:(NSString *) reference success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success {
    NSString *requestURLString = [NSString stringWithFormat:@"%@reference=%@&key=%@", BASE_PLACE_DETAIL_URL, reference, SERVER_API_KEY];
    NSURL *requestURL = [NSURL URLWithString:requestURLString];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:requestURL];
    
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    operation.responseSerializer = [AFJSONResponseSerializer serializer];
    
    [operation setCompletionBlockWithSuccess:success failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"%@", error);
    }];
    
    [operation start];
}

+ (void)fetchPlaceDetailsWithDescription:(NSString *) description withLocation:(CLLocation *)currentLocation success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success {
    NSString *requestURLString = [NSString stringWithFormat:@"%@location=%f,%f&rankby=distance&name=%@&key=%@", BASE_PLACE_SEARCH_URL, currentLocation.coordinate.latitude, currentLocation.coordinate.longitude, description, SERVER_API_KEY];
    NSURL *requestURL = [NSURL URLWithString:requestURLString];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:requestURL];
    
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    operation.responseSerializer = [AFJSONResponseSerializer serializer];
    
    [operation setCompletionBlockWithSuccess:success failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"%@", error);
    }];
    
    [operation start];
}

+ (void)fetchRouteWithStart:(CLLocation *)startLocation withEnd:(CLLocation *)endLocation success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success {
    NSString *requestURLString = [NSString stringWithFormat:@"%@origin=%f,%f&destination=%f,%f&key=%@", BASE_ROUTE_URL, startLocation.coordinate.latitude, startLocation.coordinate.longitude, endLocation.coordinate.latitude, endLocation.coordinate.longitude, SERVER_API_KEY];
    NSURL *requestURL = [NSURL URLWithString:requestURLString];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:requestURL];
    
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    operation.responseSerializer = [AFJSONResponseSerializer serializer];
    
    [operation setCompletionBlockWithSuccess:success failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"%@", error);
    }];
    
    [operation start];
}

@end
