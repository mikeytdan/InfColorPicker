//==============================================================================
//
//  MainViewController.m
//  InfColorPicker
//
//  Created by Troy Gaul on 7 Aug 2010.
//
//  Copyright (c) 2011 InfinitApps LLC - http://infinitapps.com
//	Some rights reserved: http://opensource.org/licenses/MIT
//
//==============================================================================

#import "InfColorPickerController.h"

#import "InfColorBarPicker.h"
#import "InfColorSquarePicker.h"
#import "InfHSBSupport.h"
#import "PDButton.h"

@interface UIColor (Hex)
- (CGColorSpaceModel) colorSpaceModel;
- (BOOL) canProvideRGBComponents;
@end

@implementation  UIColor (Hex)

+ (UIColor *)colorWithHexadecimalCode:(NSString *)hexadecimalString {
    NSString *cString = [[hexadecimalString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    
    // String should be 6, 7 or 8 characters
    if ([cString length] < 6) return nil;
    
    // strip 0X if it appears
    if ([cString hasPrefix:@"0X"]) cString = [cString substringFromIndex:2];
    
    // strip # if it appears
    if ([cString hasPrefix:@"#"]) cString = [cString substringFromIndex:1];
    
    if ([cString length] != 6) return nil;
    
    // Separate into r, g, b substrings
    NSRange range;
    range.location = 0;
    range.length = 2;
    NSString *rString = [cString substringWithRange:range];
    
    range.location = 2;
    NSString *gString = [cString substringWithRange:range];
    
    range.location = 4;
    NSString *bString = [cString substringWithRange:range];
    
    // Scan values
    unsigned int r, g, b;
    [[NSScanner scannerWithString:rString] scanHexInt:&r];
    [[NSScanner scannerWithString:gString] scanHexInt:&g];
    [[NSScanner scannerWithString:bString] scanHexInt:&b];
    
    return [UIColor colorWithRed:((float) r / 255.0f)
                           green:((float) g / 255.0f)
                            blue:((float) b / 255.0f)
                           alpha:1.f];
}

- (CGFloat) red {
    NSAssert (self.canProvideRGBComponents, @"Must be a RGB color to use -red, -green, -blue");
    const CGFloat *c = CGColorGetComponents(self.CGColor);
    return c[0];
}
- (CGFloat) green {
    NSAssert (self.canProvideRGBComponents, @"Must be a RGB color to use -red, -green, -blue");
    const CGFloat *c = CGColorGetComponents(self.CGColor);
    if ([self colorSpaceModel] == kCGColorSpaceModelMonochrome) return c[0];
    return c[1];
}
- (CGFloat) blue {
    NSAssert (self.canProvideRGBComponents, @"Must be a RGB color to use -red, -green, -blue");
    const CGFloat *c = CGColorGetComponents(self.CGColor);
    if ([self colorSpaceModel] == kCGColorSpaceModelMonochrome) return c[0];
    return c[2];
}

- (CGColorSpaceModel) colorSpaceModel {
    return CGColorSpaceGetModel(CGColorGetColorSpace(self.CGColor));
}

- (BOOL) canProvideRGBComponents {
    return (([self colorSpaceModel] == kCGColorSpaceModelRGB) ||
            ([self colorSpaceModel] == kCGColorSpaceModelMonochrome));
}

- (NSString *) hexString {
    NSAssert (self.canProvideRGBComponents, @"Must be a RGB color to use hexString");
    CGFloat r, g, b;
    r = self.red;
    g = self.green;
    b = self.blue;
    // Fix range if needed
    if (r < 0.0f) r = 0.0f;
        if (g < 0.0f) g = 0.0f;
            if (b < 0.0f) b = 0.0f;
                if (r > 1.0f) r = 1.0f;
                    if (g > 1.0f) g = 1.0f;
                        if (b > 1.0f) b = 1.0f;
                            // Convert to hex string between 0x00 and 0xFF
                            return [NSString stringWithFormat:@"%02X%02X%02X",
                                    (int)(r * 255), (int)(g * 255), (int)(b * 255)];
}

@end

//------------------------------------------------------------------------------

static void HSVFromUIColor( UIColor* color, float* h, float* s, float* v )
{
	CGColorRef colorRef = [ color CGColor ];
	
	const CGFloat* components = CGColorGetComponents( colorRef );
	size_t numComponents = CGColorGetNumberOfComponents( colorRef );
	
	CGFloat r, g, b;
	if( numComponents < 3 ) {
		r = g = b = components[ 0 ];
	}
	else {
		r = components[ 0 ];
		g = components[ 1 ];
		b = components[ 2 ];
	}
	
	RGBToHSV( r, g, b, h, s, v, YES );
}

//==============================================================================

@interface InfColorPickerController() <UITextFieldDelegate>

- (void) updateResultColor;

// Outlets and actions:

- (IBAction) takeBarValue: (id) sender;
- (IBAction) takeSquareValue: (id) sender;
- (IBAction) takeBackgroundColor: (UIView*) sender;
- (IBAction) done: (id) sender;

@end

//==============================================================================

@implementation InfColorPickerController

//------------------------------------------------------------------------------

@synthesize delegate, resultColor, sourceColor;
@synthesize barView, squareView;
@synthesize barPicker, squarePicker;
@synthesize sourceColorView,  resultColorView;
@synthesize navController;
@synthesize hexTextField;

//------------------------------------------------------------------------------
#pragma mark	Class methods
//------------------------------------------------------------------------------

+ (InfColorPickerController*) colorPickerViewController
{
	return [ [ [ self alloc ] initWithNibName: @"InfColorPickerView" bundle: nil ] autorelease ];
}

//------------------------------------------------------------------------------

+ (CGSize) idealSizeForViewInPopover
{
	return CGSizeMake( 256 + ( 1 + 20 ) * 2, 420 );
}

//------------------------------------------------------------------------------
#pragma mark	Memory management
//------------------------------------------------------------------------------

- (void) dealloc
{
	[ barView release ];
	[ squareView release ];
	[ barPicker release ];
	[ squarePicker release ];
	[ sourceColorView release ];
	[ resultColorView release ];
	[ navController release ];
	
	[ sourceColor release ];
	[ resultColor release ];
	
    [hexTextField release];
	[ super dealloc ];
}

//------------------------------------------------------------------------------
#pragma mark	Creation
//------------------------------------------------------------------------------

- (id) initWithNibName: (NSString*) nibNameOrNil bundle: (NSBundle*) nibBundleOrNil
{
	self = [ super initWithNibName: nibNameOrNil bundle: nibBundleOrNil ];
	
	if( self ) {
		self.navigationItem.title = NSLocalizedString( @"Set Color", 
									@"InfColorPicker default nav item title" );
	}
	
	return self;
}

//------------------------------------------------------------------------------

- (void) viewDidLoad
{
	[ super viewDidLoad ];

	self.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    
    CGFloat nBHeight = (([UIScreen mainScreen].bounds.size.height == 568)) ? 50 : 46;   
    PDButton *cancelButton = [PDButton buttonWithType:UIButtonTypeCustom];
    cancelButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    cancelButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    cancelButton.titleLabel.textColor = [UIColor whiteColor];
    [cancelButton addTarget:self action:@selector(cancelColorPicker) forControlEvents:UIControlEventTouchUpInside];
    [cancelButton setTitle:NSLocalizedString(@"CANCEL", nil) forState:UIControlStateNormal];
    cancelButton.frame = CGRectMake(0, 0, 100, 100); //fake
    CGRect cancelButtonFrame = cancelButton.titleLabel.frame;
    cancelButtonFrame.size.width += 20;
    cancelButtonFrame.size.height += 20;
    cancelButtonFrame.origin.x = 7;
    cancelButtonFrame.origin.y = (nBHeight / 2) - (cancelButtonFrame.size.height / 2);
    cancelButton.frame = cancelButtonFrame;

    [self.navigationController.navigationBar addSubview:cancelButton];
    
    self.hexTextField.delegate = self;
    
	barPicker.value = hue;
	squareView.hue = hue;
	squarePicker.hue = hue;
	squarePicker.value = CGPointMake( saturation, brightness );

	if( sourceColor )
    {
		sourceColorView.backgroundColor = sourceColor;
    }
	
	if( resultColor )
    {
		resultColorView.backgroundColor = resultColor;
    }
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideKeyboard)];
    [self.view addGestureRecognizer:tap];
}

//------------------------------------------------------------------------------

- (void) viewDidUnload
{
    [self setHexTextField:nil];
	[ super viewDidUnload ];
	
	// Release any retained subviews of the main view.
	
	self.barView = nil;
	self.squareView = nil;
	self.barPicker = nil;
	self.squarePicker = nil;
	self.sourceColorView = nil;
	self.resultColorView = nil;
	self.navController = nil;
}

//------------------------------------------------------------------------------

- (BOOL) shouldAutorotateToInterfaceOrientation: (UIInterfaceOrientation) interfaceOrientation
{
	return interfaceOrientation == UIInterfaceOrientationPortrait;
}

//------------------------------------------------------------------------------

- (void) presentModallyOverViewController: (UIViewController*) controller
{
	UINavigationController* nav = [ [ [ UINavigationController alloc ] initWithRootViewController: self ] autorelease ];
	
	nav.navigationBar.barStyle = UIBarStyleBlackOpaque;
	    
    CGFloat nBHeight = (([UIScreen mainScreen].bounds.size.height == 568)) ? 50 : 46;
    PDButton *doneButton = [PDButton buttonWithType:UIButtonTypeCustom];
    doneButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    doneButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    doneButton.titleLabel.textColor = [UIColor whiteColor];
    [doneButton addTarget:self action:@selector(done:) forControlEvents:UIControlEventTouchUpInside];
    [doneButton setTitle:NSLocalizedString(@"DONE", nil) forState:UIControlStateNormal];
    doneButton.frame = CGRectMake(0, 0, 100, 100); //fake, but otherwise button.titleLabel.frame will be CGRectZero
    CGRect doneButtonFrame = doneButton.titleLabel.frame;
    doneButtonFrame.size.width += 20;
    doneButtonFrame.size.height += 20;
    doneButtonFrame.origin.x = self.view.frame.size.width - doneButtonFrame.size.width - 4;
    doneButtonFrame.origin.y = (nBHeight / 2) - (doneButtonFrame.size.height / 2);
    doneButton.frame = doneButtonFrame;
    [self.navigationController.navigationBar addSubview:doneButton];
				
	[ controller presentModalViewController: nav animated: YES ];
}

//------------------------------------------------------------------------------
#pragma mark	IB actions
//------------------------------------------------------------------------------

- (IBAction) takeBarValue: (InfColorBarPicker*) sender
{
	hue = sender.value;
	
	squareView.hue = hue;
	squarePicker.hue = hue;
	
	[ self updateResultColor ];
}

//------------------------------------------------------------------------------

- (IBAction) takeSquareValue: (InfColorSquarePicker*) sender
{
	saturation = sender.value.x;
	brightness = sender.value.y;

	[ self updateResultColor ];
}

//------------------------------------------------------------------------------

- (IBAction) takeBackgroundColor: (UIView*) sender
{
	self.resultColor = sender.backgroundColor;
}

//------------------------------------------------------------------------------

- (IBAction) done: (id) sender
{
	[ self.delegate colorPickerControllerDidFinish: self ];	
}

- (void) closeColorPicker {
    [ self.delegate colorPickerControllerDidFinish: self ];
}

- (void) cancelColorPicker {
    [ self.delegate colorPickerControllerDidCancel: self ];
}

//------------------------------------------------------------------------------
#pragma mark	Properties
//------------------------------------------------------------------------------

- (void) informDelegateDidChangeColor
{
	if( self.delegate && [ (id) self.delegate respondsToSelector: @selector( colorPickerControllerDidChangeColor: ) ] )
		[ self.delegate colorPickerControllerDidChangeColor: self ];
}

//------------------------------------------------------------------------------

- (void) updateResultColor
{
	// This is used when code internally causes the update.  We do this so that
	// we don't cause push-back on the HSV values in case there are rounding
	// differences or anything.  However, given protections from hue and sat
	// changes when not necessary elsewhere it's probably not actually needed.
	
	[ self willChangeValueForKey: @"resultColor" ];
	
	[ resultColor release ];
	resultColor = [ [ UIColor colorWithHue: hue saturation: saturation 
								brightness: brightness alpha: 1.0f ] retain ];
	
	[ self didChangeValueForKey: @"resultColor" ];
	
	resultColorView.backgroundColor = resultColor;
	
	[ self informDelegateDidChangeColor ];
    
    self.hexTextField.text = [NSString stringWithFormat:@"#%@", [resultColor hexString]];
}

//------------------------------------------------------------------------------

- (void) setResultColor: (UIColor*) newValue
{
	if( ![ resultColor isEqual: newValue ] ) {
		[ resultColor release ];
		resultColor = [ newValue retain ];
		
		float h = hue;
		HSVFromUIColor( newValue, &h, &saturation, &brightness );
		
		if( h != hue ) {
			hue = h;
			
			barPicker.value = hue;
			squareView.hue = hue;
			squarePicker.hue = hue;
		}
		
		squarePicker.value = CGPointMake( saturation, brightness );

		resultColorView.backgroundColor = resultColor;

		[ self informDelegateDidChangeColor ];
	}
}

//------------------------------------------------------------------------------

- (void) setSourceColor: (UIColor*) newValue
{
	if( ![ sourceColor isEqual: newValue ] ) {
		[ sourceColor release ];
		sourceColor = [ newValue retain ];
		
		sourceColorView.backgroundColor = sourceColor;
		
		self.resultColor = newValue;
	}
}

//------------------------------------------------------------------------------
#pragma mark	UIViewController( UIPopoverController ) methods
//------------------------------------------------------------------------------

- (CGSize) contentSizeForViewInPopover
{
	return [ [ self class ] idealSizeForViewInPopover ];
}

//------------------------------------------------------------------------------

#pragma mark    UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *newString = [[textField.text stringByReplacingCharactersInRange:range withString:string] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    NSRange rangeOfHash = [newString rangeOfString:@"#"];
    if (rangeOfHash.location != 0) {
        return NO;
    }
    
    if (newString.length > 7) {
        return NO;
    }
    
    UIColor *colour = [UIColor colorWithHexadecimalCode:newString];
    if (colour) {
        [self setResultColor:colour];
        return NO;
    }
    
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
}

- (void)hideKeyboard {
    UIResponder *responder = [self findFirstResponder:self.view];
    [responder resignFirstResponder];
}

- (UIView *)findFirstResponder:(UIView *)aView {
    if (aView.isFirstResponder) {
        return aView;
    }
    
    for (UIView *subview in aView.subviews) {
        UIView *firstResponder = [self findFirstResponder:subview];
        
        if (firstResponder != nil) {
            return firstResponder;
        }
    }
    
    return nil;
}

@end

//==============================================================================
