//
//  OTGMapViewViewController.m
//  On The Go
//
//  Created by Eric Gao on 7/1/14.
//  Copyright (c) 2014 Eric Gao. All rights reserved.
//

#import "OTGMapViewViewController.h"
#import "OTGNetworkRequest.h"
#import "OTGSearchBarCell.h"
#import <GoogleMaps/GoogleMaps.h>
#import <CoreLocation/CoreLocation.h>

@interface OTGMapViewViewController () <UISearchBarDelegate, UISearchDisplayDelegate, UITableViewDataSource, UITableViewDelegate, GMSMapViewDelegate>

@property (nonatomic, strong) IBOutlet GMSMapView *mapView;
@property (nonatomic, strong) IBOutlet UISearchBar *startSearchBar;
@property (nonatomic, strong) IBOutlet UISearchBar *endSearchBar;
@property (nonatomic, strong) IBOutlet UIView *detailView;
@property (nonatomic, strong) IBOutlet UILabel *mainAddress;
@property (nonatomic, strong) IBOutlet UILabel *subAddress;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CLLocation *currentLocation;
@property (nonatomic, strong) UISearchDisplayController *startSearchController;
@property (nonatomic, strong) UISearchDisplayController *endSearchController;
@property (nonatomic, strong) NSMutableArray *places;
@property (nonatomic, strong) CLLocation *startLocation;
@property (nonatomic, strong) CLLocation *endLocation;
@property (nonatomic, strong) NSString *startAddress;
@property (nonatomic, strong) NSString *endAddress;
@property (nonatomic, strong) GMSMarker *startMarker;
@property (nonatomic, strong) GMSMarker *endMarker;

@end

@implementation OTGMapViewViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Remove the border from search bar
    [self.startSearchBar setBackgroundImage:[[UIImage alloc] init]];
    [self.endSearchBar setBackgroundImage:[[UIImage alloc] init]];
    
    // Set up detail view frame and gradient
    [self.detailView setFrame:CGRectMake(0, 568, 320, 55)];
    
    CAGradientLayer *layer = [CAGradientLayer layer];
    layer.frame = self.detailView.bounds;
    layer.colors = [NSArray arrayWithObjects:(id)[UIColor whiteColor].CGColor, (id)[UIColor colorWithWhite:1 alpha:0].CGColor, nil];
    layer.startPoint = CGPointMake(1.0f, 1.0f);
    layer.endPoint = CGPointMake(1.0f, 0.0f);
    [self.detailView.layer insertSublayer:layer atIndex:0];
    
    // Set up start search bar and search controller
    self.startSearchBar.delegate = self;
    self.startSearchController = [[UISearchDisplayController alloc] initWithSearchBar:self.startSearchBar contentsController:self];
    self.startSearchController.delegate = self;
    self.startSearchController.searchResultsDataSource = self;
    self.startSearchController.searchResultsDelegate = self;
    
    // Set up end search bar and search controller
    self.endSearchBar.delegate = self;
    self.endSearchController = [[UISearchDisplayController alloc] initWithSearchBar:self.endSearchBar contentsController:self];
    self.endSearchController.delegate = self;
    self.endSearchController.searchResultsDataSource = self;
    self.endSearchController.searchResultsDelegate = self;
    
    // Set up map view and center to user location
    self.mapView.delegate = self;
    
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.distanceFilter = kCLDistanceFilterNone;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
    [self.locationManager startUpdatingLocation];
    
    self.currentLocation = self.locationManager.location;
    CLLocationDegrees latitude = self.currentLocation.coordinate.latitude;
    CLLocationDegrees longitude = self.currentLocation.coordinate.longitude;
    
    GMSCameraPosition *camera = [GMSCameraPosition cameraWithLatitude:latitude longitude:longitude zoom:12];

    self.mapView.camera = camera;
    
    // Set up search bar table views
    [self.startSearchController.searchResultsTableView setTableFooterView:[[UIView alloc] initWithFrame:CGRectZero]];
    [self.endSearchController.searchResultsTableView setTableFooterView:[[UIView alloc] initWithFrame:CGRectZero]];
}

// Searches for suggested places when user inputs an address
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [OTGNetworkRequest fetchPotentialPlacesWithString:searchText withLocation:self.currentLocation success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = responseObject;
        
        NSArray *predictions = [json valueForKey:@"predictions"];
        self.places = [[NSMutableArray alloc] init];
        for (NSDictionary *place in predictions) {
            [self.places addObject:@{@"description":[place valueForKey:@"description"],
                                            @"reference":[place valueForKey:@"reference"]}];
        }
        if (searchBar == self.startSearchBar) {
            [self.startSearchController.searchResultsTableView reloadData];
        }
    }];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // When a place is selected, zoom in to the point and drop a marker
    NSString *reference = self.places[indexPath.row][@"reference"];
    [OTGNetworkRequest fetchPlaceDetailsWithReference:reference success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = responseObject;
        NSDictionary *result = [json valueForKey:@"result"];
        CLLocationDegrees latitude = [result[@"geometry"][@"location"][@"lat"] doubleValue];
        CLLocationDegrees longitude = [result[@"geometry"][@"location"][@"lng"] doubleValue];
        
        if (tableView == self.startSearchController.searchResultsTableView) {
            [self.startSearchController setActive:NO animated:YES];
            self.endSearchBar.hidden = NO;
            
            self.startAddress = result[@"formatted_address"];
            self.startLocation = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
            
            GMSCameraPosition *startPosition = [GMSCameraPosition cameraWithLatitude:self.startLocation.coordinate.latitude longitude:self.startLocation.coordinate.longitude zoom:15];
            [self.mapView setCamera:startPosition];
            
            CLLocationCoordinate2D position = CLLocationCoordinate2DMake(latitude, longitude);
            self.startMarker.map = nil;
            self.startMarker = [GMSMarker markerWithPosition:position];
            self.startMarker.title = @"Start Location";
            self.startMarker.map = self.mapView;
            [self showDetailViewForMarker:self.startMarker];
        } else if (tableView == self.endSearchController.searchResultsTableView) {
            [self.endSearchController setActive:NO animated:YES];
            
            self.endAddress = result[@"formatted_address"];
            self.endLocation = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
            
            GMSCameraPosition *endPosition = [GMSCameraPosition cameraWithLatitude:self.startLocation.coordinate.latitude longitude:self.startLocation.coordinate.longitude zoom:15];
            [self.mapView setCamera:endPosition];
            
            CLLocationCoordinate2D position = CLLocationCoordinate2DMake(latitude, longitude);
            self.endMarker.map = nil;
            self.endMarker = [GMSMarker markerWithPosition:position];
            self.endMarker.title = @"End Location";
            self.endMarker.map = self.mapView;
            [self showDetailViewForMarker:self.endMarker];
            
            [OTGNetworkRequest fetchRouteWithStart:self.startLocation withEnd:self.endLocation success:^(AFHTTPRequestOperation *operation, id responseObject) {
                NSDictionary *json = responseObject;
                NSArray *routes = json[@"routes"];
                
            }];
        }
    }];
}

#pragma Table View Delegate
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    OTGSearchBarCell *cell = [[OTGSearchBarCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"placeCell"];
    cell.textLabel.text = self.places[indexPath.row][@"description"];
    cell.reference = self.places[indexPath.row][@"reference"];
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.places count];
}

#pragma Map View Delegate
- (BOOL)mapView:(GMSMapView *)mapView didTapMarker:(GMSMarker *)marker {
    [self showDetailViewForMarker:marker];
    return YES;
}

- (void)mapView:(GMSMapView *)mapView didTapAtCoordinate:(CLLocationCoordinate2D)coordinate {
    // Hide the detail view
    [UIView animateWithDuration:0.2 animations:^{
        self.detailView.frame = CGRectMake(0, 568, 320, 55);
    }];
}

- (void)showDetailViewForMarker:(GMSMarker *)marker {
    [self.view addSubview:self.detailView];
    if (marker == self.startMarker) {
        NSRange range = [self.startAddress rangeOfString:@","];
        if (range.location < self.startAddress.length) {
            NSString *mainAddress = [self.startAddress substringToIndex:range.location];
            NSString *subAddress = [self.startAddress substringFromIndex:range.location + 2];
            self.mainAddress.text = mainAddress;
            self.subAddress.text = subAddress;
        } else {
            self.mainAddress.text = self.startAddress;
        }
    } else if (marker == self.endMarker) {
        NSRange range = [self.endAddress rangeOfString:@","];
        if (range.location < self.endAddress.length) {
            NSString *mainAddress = [self.endAddress substringToIndex:range.location];
            NSString *subAddress = [self.endAddress substringFromIndex:range.location + 2];
            self.mainAddress.text = mainAddress;
            self.subAddress.text = subAddress;
        } else {
            self.mainAddress.text = self.endAddress;
        }
    }
    
    [UIView animateWithDuration:0.2 animations:^{
        self.detailView.frame = CGRectMake(0, 513, 320, 55);
    }];
}

@end
