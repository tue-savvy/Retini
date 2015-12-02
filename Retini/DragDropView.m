//
//  DragDropView.m
//  Retini
//
//  Created by Erik Terwan on 16-06-15.
//  Copyright (c) 2015 ET-ID. All rights reserved.
//

#import "DragDropView.h"
#import "NSImage+Resize.h" // File from https://github.com/nate-parrott/Flashlight

// I'm going to refractor this aswell, put everything that should be in a model, in a model.

@implementation DragDropView

@synthesize pngCrushLoader;
@synthesize highlight, notFound;

- (id)initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];
	
	if(self){
		[self registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
		
		[pngCrushLoader setAlphaValue:0.0];
	}
	
	return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	
	if(self){
		[self registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
		
		[pngCrushLoader setAlphaValue:0.0];
	}
	
	return self;
}

- (void)awakeFromNib
{
	[pngCrushLoader setAlphaValue:0.0];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	highlight = YES;
	notFound = NO;
	
	NSArray *draggedFilenames = [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
	
	if(![self hasRetinaFiles:draggedFilenames]){
		notFound = YES;
	}
	
	[self setNeedsDisplay:YES];
	
	return NSDragOperationCopy;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
	highlight = NO;
	notFound = NO;
	
	[self setNeedsDisplay:YES];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	highlight = NO;
	notFound = NO;
	
	[self setNeedsDisplay:YES];
	
	return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	NSArray *draggedFilenames = [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
	
	if(![self hasRetinaFiles:draggedFilenames]){
		notFound = YES;
		
		[self setNeedsDisplay:YES];
	}
	
	return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
	NSArray *draggedFilenames = [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
	
	[self checkFiles:draggedFilenames];
	
	highlight = NO;
	notFound = NO;
	
	[self setNeedsDisplay:YES];
}

- (BOOL)hasRetinaFiles:(NSArray *)fileNames
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	for(NSString *filename in fileNames){
		BOOL isDir;
		
		if([fileManager fileExistsAtPath:filename isDirectory:&isDir]){
			if(!isDir){
				if([filename containsString:@"@2x"] || [filename containsString:@"@3x"]){
					return YES;
				}
			} else{
				NSMutableArray *dirContents = [NSMutableArray array];
				
				for(NSString *file in [fileManager contentsOfDirectoryAtPath:filename error:nil]){
					[dirContents addObject:[[filename stringByAppendingString:@"/"] stringByAppendingString:file]];
				}
				
				return [self hasRetinaFiles:dirContents];
			}
		}
	}
	
	return NO;
}

- (void)checkFiles:(NSArray *)fileNames
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	for(NSString *filename in fileNames){
		BOOL isDir;
		
		if([fileManager fileExistsAtPath:filename isDirectory:&isDir]){
			if(!isDir){
				[self workFile:filename];
			} else{
				NSMutableArray *dirContents = [NSMutableArray array];
				
				for(NSString *file in [fileManager contentsOfDirectoryAtPath:filename error:nil]){
					[dirContents addObject:[[filename stringByAppendingString:@"/"] stringByAppendingString:file]];
				}
				
				[self checkFiles:dirContents];
			}
		}
	}
}

- (void)workFile:(NSString *)file
{
	if([[file lowercaseString] containsString:@"png"] || [[file lowercaseString] containsString:@"jpeg"] || [[file lowercaseString] containsString:@"jpg"]){
		if([[file lowercaseString] containsString:@"@3x"]){
			[self resize3x:file];
		} else if([[file lowercaseString] containsString:@"@2x"]){
			[self resize2x:file];
		}
	}
}


- (void)resize3x:(NSString *)fileName
{
	NSImage *original = [[NSImage alloc] initWithContentsOfFile:fileName];
    CGSize originalSize = CGSizeMake(original.size.width / 3, original.size.height / 3);
	NSImage *newImg2x = [self imageResize:[original copy] newSize:NSMakeSize(originalSize.width * 2, originalSize.height * 2)];
	
	if([self saveImage:newImg2x toPath:[fileName stringByReplacingOccurrencesOfString:@"@3x" withString:@"@2x"]]){
		NSImage *newImg = [self imageResize:[original copy] newSize:NSMakeSize(originalSize.width, originalSize.height)];
		[self saveImage:newImg toPath:[fileName stringByReplacingOccurrencesOfString:@"@3x" withString:@""]];
	}
	
	if([[NSUserDefaults standardUserDefaults] integerForKey:@"pngOut"] == 1){
		[self crushPng:fileName];
	}
}

- (void)resize2x:(NSString *)fileName
{
	NSImage *original = [[NSImage alloc] initWithContentsOfFile:fileName];
    CGSize originalSize = CGSizeMake(original.size.width / 2, original.size.height / 2);
	NSImage *newImg = [self imageResize:original newSize:NSMakeSize(originalSize.width, originalSize.height)];
	
	[self saveImage:newImg toPath:[fileName stringByReplacingOccurrencesOfString:@"@2x" withString:@""]];
	
	if([[NSUserDefaults standardUserDefaults] integerForKey:@"pngOut"] == 1){
		[self crushPng:fileName];
	}
}

- (NSImage *)imageResize:(NSImage *)anImage newSize:(NSSize)newSize
{
	return [anImage resizeImageToSize:newSize];
}

- (BOOL)saveImage:(NSImage *)image toPath:(NSString *)path
{
	if(image != nil){
		[image lockFocus];
		
		NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0.0, 0.0, [image size].width, [image size].height)];
		
		[image unlockFocus] ;
		
		NSUInteger fileType = NSJPEGFileType;
		
		if([path containsString:@"png"]){
			fileType = NSPNGFileType;
		}
		
		float quality = 1.0;
		
		if([[NSUserDefaults standardUserDefaults] integerForKey:@"jpegQuality"]){
			quality = [[NSUserDefaults standardUserDefaults] integerForKey:@"jpegQuality"] / 10;
		}
		
		NSData *data = [bitmapRep representationUsingType:fileType properties:[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:quality] forKey:NSImageCompressionFactor]];
		
		if([[NSUserDefaults standardUserDefaults] integerForKey:@"pngOut"] == 1){
			if([data writeToFile:path atomically:YES]){
				return [self crushPng:path];
			}
		}
		
		return [data writeToFile:path atomically:YES];
	}
	
	return NO;
}

- (BOOL)crushPng:(NSString *)fileName
{
	if(![[fileName lowercaseString] containsString:@"png"]){
		return NO;
	}
	
	[pngCrushLoader setMaxValue:pngCrushLoader.maxValue + 1];
	[pngCrushLoader setAlphaValue:1.0];
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		NSTask *task = [[NSTask alloc] init];
		task.launchPath = [[NSBundle mainBundle] pathForResource:@"pngout" ofType:@""];
		task.arguments = @[@"-y", fileName, fileName];
		
		[task launch];
		[task waitUntilExit];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			[pngCrushLoader setDoubleValue:pngCrushLoader.doubleValue + 1];
			
			if(pngCrushLoader.doubleValue == pngCrushLoader.maxValue){
				[pngCrushLoader setAlphaValue:0.0];
				[pngCrushLoader setDoubleValue:0];
				[pngCrushLoader setMaxValue:0];
			}
		});
	});
	
	return YES;
}

- (void)drawRect:(NSRect)rect
{
	[super drawRect:rect];
	
	if(notFound){
		[[NSImage imageNamed:@"homeScreen~noFind"] drawInRect:rect];
	} else if(highlight){
		[[NSImage imageNamed:@"homeScreen~drop"] drawInRect:rect];
	} else{
		[[NSImage imageNamed:@"homeScreen"] drawInRect:rect];
	}
}

@end
