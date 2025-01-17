
#import <Foundation/Foundation.h>

@interface NSFileManager (MNZCategory)

#pragma mark - Paths

- (NSString *)downloadsDirectory;
- (NSString *)uploadsDirectory;

#pragma mark - Remove files and folders

- (void)mnz_removeItemAtPath:(NSString *)path;
- (void)mnz_removeFolderContentsAtPath:(NSString *)folderPath;
- (void)mnz_removeFolderContentsAtPath:(NSString *)folderPath forItemsContaining:(NSString *)filesContaining;
- (void)mnz_removeFolderContentsRecursivelyAtPath:(NSString *)folderPath forItemsContaining:(NSString *)itemsContaining;
- (void)mnz_removeFolderContentsRecursivelyAtPath:(NSString *)folderPath forItemsExtension:(NSString *)itemsExtension;

- (void)mnz_moveItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath;

@end
