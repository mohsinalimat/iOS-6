
#import "MEGANode+MNZCategory.h"

#import <Photos/Photos.h>

#import "SAMKeychain.h"
#import "SVProgressHUD.h"

#import "DevicePermissionsHelper.h"
#import "Helper.h"
#import "MEGAMoveRequestDelegate.h"
#import "MEGANodeList+MNZCategory.h"
#import "MEGALinkManager.h"
#import "MEGAReachabilityManager.h"
#import "MEGARemoveRequestDelegate.h"
#import "MEGARenameRequestDelegate.h"
#import "MEGAShareRequestDelegate.h"
#import "MEGAStore.h"
#import "NSFileManager+MNZCategory.h"
#import "NSString+MNZCategory.h"
#import "UIApplication+MNZCategory.h"

#import "BrowserViewController.h"
#import "CloudDriveViewController.h"
#import "MainTabBarController.h"
#import "MEGAAVViewController.h"
#import "MEGANavigationController.h"
#import "MEGAPhotoBrowserViewController.h"
#import "MEGAQLPreviewController.h"
#import "OnboardingViewController.h"
#import "PreviewDocumentViewController.h"
#import "SharedItemsViewController.h"

@implementation MEGANode (MNZCategory)

- (void)navigateToParentAndPresent {
    MainTabBarController *mainTBC = (MainTabBarController *) UIApplication.sharedApplication.delegate.window.rootViewController;
    
    if ([[MEGASdkManager sharedMEGASdk] accessLevelForNode:self] != MEGAShareTypeAccessOwner) { // Node from inshare
        mainTBC.selectedIndex = SHARES;
        SharedItemsViewController *sharedItemsVC = mainTBC.childViewControllers[SHARES].childViewControllers.firstObject;
        [sharedItemsVC selectSegment:0]; // Incoming
    } else {
        mainTBC.selectedIndex = CLOUD;
    }
    
    UINavigationController *navigationController = [mainTBC.childViewControllers objectAtIndex:mainTBC.selectedIndex];
    [navigationController popToRootViewControllerAnimated:NO];
    
    NSArray *parentTreeArray = self.mnz_parentTreeArray;
    for (MEGANode *node in parentTreeArray) {
        CloudDriveViewController *cloudDriveVC = [[UIStoryboard storyboardWithName:@"Cloud" bundle:nil] instantiateViewControllerWithIdentifier:@"CloudDriveID"];
        cloudDriveVC.parentNode = node;
        [navigationController pushViewController:cloudDriveVC animated:NO];
    }
    
    switch (self.type) {
        case MEGANodeTypeFolder:
        case MEGANodeTypeRubbish: {
            CloudDriveViewController *cloudDriveVC = [[UIStoryboard storyboardWithName:@"Cloud" bundle:nil] instantiateViewControllerWithIdentifier:@"CloudDriveID"];
            cloudDriveVC.parentNode = self;
            [navigationController pushViewController:cloudDriveVC animated:NO];
            break;
        }
            
        case MEGANodeTypeFile: {
            if (self.name.mnz_isImagePathExtension || self.name.mnz_isVideoPathExtension) {
                MEGANode *parentNode = [[MEGASdkManager sharedMEGASdk] nodeForHandle:self.parentHandle];
                MEGANodeList *nodeList = [[MEGASdkManager sharedMEGASdk] childrenForParent:parentNode];
                NSMutableArray<MEGANode *> *mediaNodesArray = [nodeList mnz_mediaNodesMutableArrayFromNodeList];
                
                DisplayMode displayMode = [[MEGASdkManager sharedMEGASdk] accessLevelForNode:self] == MEGAShareTypeAccessOwner ? DisplayModeCloudDrive : DisplayModeSharedItem;
                MEGAPhotoBrowserViewController *photoBrowserVC = [MEGAPhotoBrowserViewController photoBrowserWithMediaNodes:mediaNodesArray api:[MEGASdkManager sharedMEGASdk] displayMode:displayMode presentingNode:self preferredIndex:0];
                
                [navigationController presentViewController:photoBrowserVC animated:YES completion:nil];
            } else {
                [self mnz_openNodeInNavigationController:navigationController folderLink:NO];
            }
            break;
        }
            
        default:
            break;
    }
}

- (void)mnz_openNodeInNavigationController:(UINavigationController *)navigationController folderLink:(BOOL)isFolderLink {
    MEGAHandleList *chatRoomIDsWithCallInProgress = [MEGASdkManager.sharedMEGAChatSdk chatCallsWithState:MEGAChatCallStatusInProgress];
    if (self.name.mnz_isMultimediaPathExtension && chatRoomIDsWithCallInProgress.size > 0) {
        [Helper cannotPlayContentDuringACallAlert];
    } else {
        UIViewController *viewController = [self mnz_viewControllerForNodeInFolderLink:isFolderLink];
        if (viewController) {
            [navigationController presentViewController:viewController animated:YES completion:nil];
        }
    }
}

- (UIViewController *)mnz_viewControllerForNodeInFolderLink:(BOOL)isFolderLink {
    MEGASdk *api = isFolderLink ? [MEGASdkManager sharedMEGASdkFolder] : [MEGASdkManager sharedMEGASdk];
    MEGASdk *apiForStreaming = [MEGASdkManager sharedMEGASdk].isLoggedIn ? [MEGASdkManager sharedMEGASdk] : [MEGASdkManager sharedMEGASdkFolder];
    
    MOOfflineNode *offlineNodeExist = [[MEGAStore shareInstance] offlineNodeWithNode:self];
    
    NSString *previewDocumentPath = nil;
    if (offlineNodeExist) {
        previewDocumentPath = [[Helper pathForOffline] stringByAppendingPathComponent:offlineNodeExist.localPath];
    } else {
        NSString *nodeFolderPath = [NSTemporaryDirectory() stringByAppendingPathComponent:self.base64Handle];
        NSString *tmpFilePath = [nodeFolderPath stringByAppendingPathComponent:self.name];
        if ([[NSFileManager defaultManager] fileExistsAtPath:tmpFilePath isDirectory:nil]) {
            previewDocumentPath = tmpFilePath;
        }
    }
    
    if (previewDocumentPath) {
        if (self.name.mnz_isMultimediaPathExtension) {
            NSURL *path = [NSURL fileURLWithPath:previewDocumentPath];
            AVURLAsset *asset = [AVURLAsset assetWithURL:path];
            
            if (asset.playable) {
                MEGAAVViewController *megaAVViewController = [[MEGAAVViewController alloc] initWithURL:path];
                return megaAVViewController;
            } else {
                MEGAQLPreviewController *previewController = [[MEGAQLPreviewController alloc] initWithFilePath:previewDocumentPath];
                previewController.currentPreviewItemIndex = 0;
                
                return previewController;
            }
        } else if (@available(iOS 11.0, *)) {
            if ([previewDocumentPath.pathExtension isEqualToString:@"pdf"]) {
                MEGANavigationController *navigationController = [[UIStoryboard storyboardWithName:@"Cloud" bundle:nil] instantiateViewControllerWithIdentifier:@"previewDocumentNavigationID"];
                PreviewDocumentViewController *previewController = navigationController.viewControllers.firstObject;
                previewController.api = api;
                previewController.filesPathsArray = @[previewDocumentPath];
                previewController.nodeFileIndex = 0;
                previewController.node = self;
                previewController.isLink = isFolderLink;
                
                return navigationController;
            } else {
                MEGAQLPreviewController *previewController = [[MEGAQLPreviewController alloc] initWithFilePath:previewDocumentPath];
                previewController.currentPreviewItemIndex = 0;
                
                return previewController;
            }
        } else {
            MEGAQLPreviewController *previewController = [[MEGAQLPreviewController alloc] initWithFilePath:previewDocumentPath];
            previewController.currentPreviewItemIndex = 0;
            
            return previewController;
        }
    } else if (self.name.mnz_isMultimediaPathExtension && [apiForStreaming httpServerStart:NO port:4443]) {
        if (self.mnz_isPlayable) {
            MEGAAVViewController *megaAVViewController = [[MEGAAVViewController alloc] initWithNode:self folderLink:isFolderLink apiForStreaming:apiForStreaming];
            return megaAVViewController;
        } else {
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"fileNotSupported", @"Alert title shown when users try to stream an unsupported audio/video file") message:AMLocalizedString(@"message_fileNotSupported", @"Alert message shown when users try to stream an unsupported audio/video file") preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"ok", nil) style:UIAlertActionStyleCancel handler:nil]];
            return alertController;
        }
    } else {
        if ([Helper isFreeSpaceEnoughToDownloadNode:self isFolderLink:isFolderLink]) {
            MEGANavigationController *navigationController = [[UIStoryboard storyboardWithName:@"Cloud" bundle:nil] instantiateViewControllerWithIdentifier:@"previewDocumentNavigationID"];
            PreviewDocumentViewController *previewController = navigationController.viewControllers.firstObject;
            previewController.node = self;
            previewController.api = api;
            previewController.isLink = isFolderLink;
            return navigationController;
        }
        return nil;
    }
}

- (void)mnz_generateThumbnailForVideoAtPath:(NSURL *)path {
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:path options:nil];
    AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    generator.appliesPreferredTrackTransform = YES;
    CMTime requestedTime = CMTimeMake(1, 60);
    CGImageRef imgRef = [generator copyCGImageAtTime:requestedTime actualTime:NULL error:NULL];
    UIImage *image = [[UIImage alloc] initWithCGImage:imgRef];
    
    NSString *tmpImagePath = [[NSTemporaryDirectory() stringByAppendingPathComponent:self.base64Handle] stringByAppendingPathExtension:@"jpg"];
    
    [UIImageJPEGRepresentation(image, 1) writeToFile:tmpImagePath atomically:YES];
    
    CGImageRelease(imgRef);
    
    NSString *thumbnailFilePath = [Helper pathForNode:self inSharedSandboxCacheDirectory:@"thumbnailsV3"];
    [[MEGASdkManager sharedMEGASdk] createThumbnail:tmpImagePath destinatioPath:thumbnailFilePath];
    [[MEGASdkManager sharedMEGASdk] setThumbnailNode:self sourceFilePath:thumbnailFilePath];
    
    NSString *previewFilePath = [Helper pathForNode:self searchPath:NSCachesDirectory directory:@"previewsV3"];
    [[MEGASdkManager sharedMEGASdk] createPreview:tmpImagePath destinatioPath:previewFilePath];
    [[MEGASdkManager sharedMEGASdk] setPreviewNode:self sourceFilePath:previewFilePath];
    
    [NSFileManager.defaultManager mnz_removeItemAtPath:tmpImagePath];
}

#pragma mark - Actions

- (BOOL)mnz_downloadNodeOverwriting:(BOOL)overwrite {
    return [self mnz_downloadNodeOverwriting:overwrite api:[MEGASdkManager sharedMEGASdk]];
}

- (BOOL)mnz_downloadNodeOverwriting:(BOOL)overwrite api:(MEGASdk *)api {
    MOOfflineNode *offlineNodeExist = [[MEGAStore shareInstance] offlineNodeWithNode:self];
    if (offlineNodeExist) {
        return YES;
    } else {
        if ([MEGAReachabilityManager isReachableHUDIfNot]) {
            BOOL isFolderLink = api != [MEGASdkManager sharedMEGASdk];
            if ([Helper isFreeSpaceEnoughToDownloadNode:self isFolderLink:isFolderLink]) {
                [Helper downloadNode:self folderPath:[Helper relativePathForOffline] isFolderLink:isFolderLink shouldOverwrite:overwrite];
                return YES;
            } else {
                return NO;
            }
        } else {
            return NO;
        }
    }
}

- (void)mnz_saveToPhotosWithApi:(MEGASdk *)api {
    [DevicePermissionsHelper photosPermissionWithCompletionHandler:^(BOOL granted) {
        if (granted) {
            [SVProgressHUD showImage:[UIImage imageNamed:@"saveToPhotos"] status:AMLocalizedString(@"Saving to Photos…", @"Text shown when starting the process to save a photo or video to Photos app")];
            NSString *temporaryPath = [[NSTemporaryDirectory() stringByAppendingPathComponent:self.base64Handle] stringByAppendingPathComponent:self.name];
            NSString *temporaryFingerprint = [MEGASdkManager.sharedMEGASdk fingerprintForFilePath:temporaryPath];
            if ([temporaryFingerprint isEqualToString:self.fingerprint]) {
                [self mnz_copyToGalleryFromTemporaryPath:temporaryPath];
            } else if (MEGAReachabilityManager.isReachableHUDIfNot) {
                NSString *downloadsDirectory = [NSFileManager.defaultManager downloadsDirectory];
                downloadsDirectory = downloadsDirectory.mnz_relativeLocalPath;
                NSString *offlineNameString = [MEGASdkManager.sharedMEGASdkFolder escapeFsIncompatible:self.name];
                NSString *localPath = [downloadsDirectory stringByAppendingPathComponent:offlineNameString];
                [MEGASdkManager.sharedMEGASdk startDownloadNode:[api authorizeNode:self] localPath:localPath appData:[[NSString new] mnz_appDataToSaveInPhotosApp]];
            }
        } else {
            [DevicePermissionsHelper alertPhotosPermission];
        }
    }];
}

- (void)mnz_renameNodeInViewController:(UIViewController *)viewController {
    [self mnz_renameNodeInViewController:viewController completion:nil];
}

- (void)mnz_renameNodeInViewController:(UIViewController *)viewController completion:(void(^)(MEGARequest *request))completion {
    if ([MEGAReachabilityManager isReachableHUDIfNot]) {
        UIAlertController *renameAlertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"rename", @"Title for the action that allows you to rename a file or folder") message:AMLocalizedString(@"renameNodeMessage", @"Hint text to suggest that the user have to write the new name for the file or folder") preferredStyle:UIAlertControllerStyleAlert];
        
        [renameAlertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            textField.text = self.name;
            textField.returnKeyType = UIReturnKeyDone;
            textField.delegate = self;
            [textField addTarget:self action:@selector(renameAlertTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        }];
        
        [renameAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", @"Button title to cancel something") style:UIAlertActionStyleCancel handler:nil]];
        
        UIAlertAction *renameAlertAction = [UIAlertAction actionWithTitle:AMLocalizedString(@"rename", @"Title for the action that allows you to rename a file or folder") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            if ([MEGAReachabilityManager isReachableHUDIfNot]) {
                UITextField *alertViewTextField = renameAlertController.textFields.firstObject;
                MEGANode *parentNode = [[MEGASdkManager sharedMEGASdk] nodeForHandle:self.parentHandle];
                MEGANodeList *childrenNodeList = [[MEGASdkManager sharedMEGASdk] nodeListSearchForNode:parentNode searchString:alertViewTextField.text];
                
                if (self.isFolder) {
                    if ([childrenNodeList mnz_existsFolderWithName:alertViewTextField.text]) {
                        [SVProgressHUD showErrorWithStatus:AMLocalizedString(@"There is already a folder with the same name", @"A tooltip message which is shown when a folder name is duplicated during renaming or creation.")];
                    } else {
                        MEGARenameRequestDelegate *delegate = [[MEGARenameRequestDelegate alloc] initWithCompletion:completion];
                        [[MEGASdkManager sharedMEGASdk] renameNode:self newName:alertViewTextField.text delegate:delegate];
                    }
                } else {
                    if ([childrenNodeList mnz_existsFileWithName:alertViewTextField.text]) {
                        [SVProgressHUD showErrorWithStatus:AMLocalizedString(@"There is already a file with the same name", @"A tooltip message which shows when a file name is duplicated during renaming.")];
                    } else {
                        MEGARenameRequestDelegate *delegate = [[MEGARenameRequestDelegate alloc] initWithCompletion:completion];
                        [[MEGASdkManager sharedMEGASdk] renameNode:self newName:alertViewTextField.text delegate:delegate];
                    }
                }
            }
        }];
        renameAlertAction.enabled = NO;
        [renameAlertController addAction:renameAlertAction];
        
        [viewController presentViewController:renameAlertController animated:YES completion:nil];
    }
}

- (void)mnz_moveToTheRubbishBinInViewController:(UIViewController *)viewController {
    if ([MEGAReachabilityManager isReachableHUDIfNot]) {
        NSString *alertTitle = AMLocalizedString(@"moveToTheRubbishBin", @"Title for the action that allows you to 'Move to the Rubbish Bin' files or folders");
        NSString *alertMessage = (self.type == MEGANodeTypeFolder) ? AMLocalizedString(@"moveFolderToRubbishBinMessage", @"Alert message to confirm if the user wants to move to the Rubbish Bin '1 folder'") : AMLocalizedString(@"moveFileToRubbishBinMessage", @"Alert message to confirm if the user wants to move to the Rubbish Bin '1 file'");
        
        UIAlertController *moveRemoveLeaveAlertController = [UIAlertController alertControllerWithTitle:alertTitle message:alertMessage preferredStyle:UIAlertControllerStyleAlert];
        
        [moveRemoveLeaveAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", @"Button title to cancel something") style:UIAlertActionStyleCancel handler:nil]];
        
        [moveRemoveLeaveAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"ok", @"Button title to accept something") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            if ([MEGAReachabilityManager isReachableHUDIfNot]) {
                void (^completion)(void) = ^{
                    [viewController dismissViewControllerAnimated:YES completion:nil];
                };
                MEGAMoveRequestDelegate *moveRequestDelegate = [[MEGAMoveRequestDelegate alloc] initToMoveToTheRubbishBinWithFiles:(self.isFile ? 1 : 0) folders:(self.isFolder ? 1 : 0) completion:completion];
                [[MEGASdkManager sharedMEGASdk] moveNode:self newParent:[[MEGASdkManager sharedMEGASdk] rubbishNode] delegate:moveRequestDelegate];
            }
        }]];
        
        [viewController presentViewController:moveRemoveLeaveAlertController animated:YES completion:nil];
    }
}

- (void)mnz_removeInViewController:(UIViewController *)viewController {
    if ([MEGAReachabilityManager isReachableHUDIfNot]) {
        NSString *alertTitle = AMLocalizedString(@"remove", @"Title for the action that allows to remove a file or folder");
        NSString *alertMessage = (self.type == MEGANodeTypeFolder) ? AMLocalizedString(@"removeFolderToRubbishBinMessage", @"Alert message shown on the Rubbish Bin when you want to remove '1 folder'") : AMLocalizedString(@"removeFileToRubbishBinMessage", @"Alert message shown on the Rubbish Bin when you want to remove '1 file'");
        
        UIAlertController *moveRemoveLeaveAlertController = [UIAlertController alertControllerWithTitle:alertTitle message:alertMessage preferredStyle:UIAlertControllerStyleAlert];
        
        [moveRemoveLeaveAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", @"Button title to cancel something") style:UIAlertActionStyleCancel handler:nil]];
        
        [moveRemoveLeaveAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"ok", @"Button title to accept something") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            if ([MEGAReachabilityManager isReachableHUDIfNot]) {
                void (^completion)(void) = ^{
                    [viewController dismissViewControllerAnimated:YES completion:nil];
                };
                MEGARemoveRequestDelegate *removeRequestDelegate = [[MEGARemoveRequestDelegate alloc] initWithMode:1 files:(self.isFile ? 1 : 0) folders:(self.isFolder ? 1 : 0) completion:completion];
                [[MEGASdkManager sharedMEGASdk] removeNode:self delegate:removeRequestDelegate];
            }
        }]];
        
        [viewController presentViewController:moveRemoveLeaveAlertController animated:YES completion:nil];
    }
}

- (void)mnz_leaveSharingInViewController:(UIViewController *)viewController {
    if ([MEGAReachabilityManager isReachableHUDIfNot]) {
        NSString *alertTitle = AMLocalizedString(@"leaveFolder", @"Button title of the action that allows to leave a shared folder");
        NSString *alertMessage = AMLocalizedString(@"leaveShareAlertMessage", @"Alert message shown when the user tap on the leave share action for one inshare");
        
        UIAlertController *moveRemoveLeaveAlertController = [UIAlertController alertControllerWithTitle:alertTitle message:alertMessage preferredStyle:UIAlertControllerStyleAlert];
        
        [moveRemoveLeaveAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", @"Button title to cancel something") style:UIAlertActionStyleCancel handler:nil]];
        
        [moveRemoveLeaveAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"ok", @"Button title to accept something") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            if ([MEGAReachabilityManager isReachableHUDIfNot]) {
                void (^completion)(void) = ^{
                    [viewController dismissViewControllerAnimated:YES completion:nil];
                };
                MEGARemoveRequestDelegate *removeRequestDelegate = [[MEGARemoveRequestDelegate alloc] initWithMode:2 files:(self.isFile ? 1 : 0) folders:(self.isFolder ? 1 : 0) completion:completion];
                [[MEGASdkManager sharedMEGASdk] removeNode:self delegate:removeRequestDelegate];
            }
        }]];
        
        [viewController presentViewController:moveRemoveLeaveAlertController animated:YES completion:nil];
    }
}

- (void)mnz_removeSharing {
    NSMutableArray *outSharesForNodeMutableArray = [[NSMutableArray alloc] init];
    
    MEGAShareList *outSharesForNodeShareList = [[MEGASdkManager sharedMEGASdk] outSharesForNode:self];
    NSUInteger outSharesForNodeCount = outSharesForNodeShareList.size.unsignedIntegerValue;
    for (NSInteger i = 0; i < outSharesForNodeCount; i++) {
        MEGAShare *share = [outSharesForNodeShareList shareAtIndex:i];
        if (share.user != nil) {
            [outSharesForNodeMutableArray addObject:share];
        }
    }
    
    MEGAShareRequestDelegate *shareRequestDelegate = [[MEGAShareRequestDelegate alloc] initToChangePermissionsWithNumberOfRequests:outSharesForNodeMutableArray.count completion:nil];
    for (MEGAShare *share in outSharesForNodeMutableArray) {
        [[MEGASdkManager sharedMEGASdk] shareNode:self withEmail:share.user level:MEGAShareTypeAccessUnknown delegate:shareRequestDelegate];
    }
}

- (void)mnz_restore {
    if ([MEGAReachabilityManager isReachableHUDIfNot]) {
        MEGANode *restoreNode = [[MEGASdkManager sharedMEGASdk] nodeForHandle:self.restoreHandle];
        MEGAMoveRequestDelegate *moveRequestDelegate = [[MEGAMoveRequestDelegate alloc] initWithFiles:(self.isFile ? 1 : 0) folders:(self.isFolder ? 1 : 0) completion:nil];
        moveRequestDelegate.restore = YES;
        [[MEGASdkManager sharedMEGASdk] moveNode:self newParent:restoreNode delegate:moveRequestDelegate];
    }
}

#pragma mark - File links

- (void)mnz_fileLinkDownloadFromViewController:(UIViewController *)viewController isFolderLink:(BOOL)isFolderLink {
    if ([MEGAReachabilityManager isReachableHUDIfNot]) {
        if (![Helper isFreeSpaceEnoughToDownloadNode:self isFolderLink:isFolderLink]) {
            return;
        }

        if ([SAMKeychain passwordForService:@"MEGA" account:@"sessionV3"]) {
            [Helper downloadNode:self folderPath:Helper.relativePathForOffline isFolderLink:isFolderLink shouldOverwrite:NO];
            
            [viewController dismissViewControllerAnimated:YES completion:^{
                [SVProgressHUD showImage:[UIImage imageNamed:@"hudDownload"] status:AMLocalizedString(@"downloadStarted", nil)];
            }];
        } else {
            if (isFolderLink) {
                [MEGALinkManager.nodesFromLinkMutableArray addObject:self];
                MEGALinkManager.selectedOption = LinkOptionDownloadFolderOrNodes;
            } else {
                [MEGALinkManager.nodesFromLinkMutableArray addObject:self];
                MEGALinkManager.selectedOption = LinkOptionDownloadNode;
            }
            
            OnboardingViewController *onboardingVC = [OnboardingViewController instanciateOnboardingWithType:OnboardingTypeDefault];
            if (viewController.navigationController) {
                [viewController.navigationController pushViewController:onboardingVC animated:YES];
            } else {
                MEGANavigationController *navigationController = [[MEGANavigationController alloc] initWithRootViewController:onboardingVC];
                [navigationController addRightCancelButton];
                [viewController presentViewController:navigationController animated:YES completion:nil];
            }
        }
    }
}

- (void)mnz_fileLinkImportFromViewController:(UIViewController *)viewController isFolderLink:(BOOL)isFolderLink {
    if ([MEGAReachabilityManager isReachableHUDIfNot]) {
        if ([SAMKeychain passwordForService:@"MEGA" account:@"sessionV3"]) {
            [viewController dismissViewControllerAnimated:YES completion:^{
                MEGANavigationController *navigationController = [[UIStoryboard storyboardWithName:@"Cloud" bundle:nil] instantiateViewControllerWithIdentifier:@"BrowserNavigationControllerID"];
                BrowserViewController *browserVC = navigationController.viewControllers.firstObject;
                browserVC.selectedNodesArray = [NSArray arrayWithObject:self];
                [UIApplication.mnz_presentingViewController presentViewController:navigationController animated:YES completion:nil];
                
                browserVC.browserAction = isFolderLink ? BrowserActionImportFromFolderLink : BrowserActionImport;
            }];
        } else {
            if (isFolderLink) {
                [MEGALinkManager.nodesFromLinkMutableArray addObject:self];
                MEGALinkManager.selectedOption = LinkOptionImportFolderOrNodes;
            } else {
                [MEGALinkManager.nodesFromLinkMutableArray addObject:self];
                MEGALinkManager.selectedOption = LinkOptionImportNode;
            }
            
            OnboardingViewController *onboardingVC = [OnboardingViewController instanciateOnboardingWithType:OnboardingTypeDefault];
            if (viewController.navigationController) {
                [viewController.navigationController pushViewController:onboardingVC animated:YES];
            } else {
                MEGANavigationController *navigationController = [[MEGANavigationController alloc] initWithRootViewController:onboardingVC];
                [navigationController addRightCancelButton];
                [viewController presentViewController:navigationController animated:YES completion:nil];
            }
        }
    }
}

#pragma mark - Utils

- (NSMutableArray *)mnz_parentTreeArray {
    NSMutableArray *parentTreeArray = [[NSMutableArray alloc] init];
    
    if ([[MEGASdkManager sharedMEGASdk] accessLevelForNode:self] == MEGAShareTypeAccessOwner) {
        uint64_t rootHandle;
        if ([[[MEGASdkManager sharedMEGASdk] nodePathForNode:self] hasPrefix:@"//bin"]) {
            rootHandle = [[MEGASdkManager sharedMEGASdk] rubbishNode].parentHandle;
        } else {
            rootHandle = [[MEGASdkManager sharedMEGASdk] rootNode].handle;
        }
        
        uint64_t tempHandle = self.parentHandle;
        while (tempHandle != rootHandle) {
            MEGANode *tempNode = [[MEGASdkManager sharedMEGASdk] nodeForHandle:tempHandle];
            if (tempNode) {
                [parentTreeArray insertObject:tempNode atIndex:0];
                tempHandle = tempNode.parentHandle;
            } else {
                break;
            }
        }
    } else {
        MEGANode *tempNode = [[MEGASdkManager sharedMEGASdk] nodeForHandle:self.parentHandle];
        while (tempNode != nil) {
            [parentTreeArray insertObject:tempNode atIndex:0];
            tempNode = [[MEGASdkManager sharedMEGASdk] nodeForHandle:tempNode.parentHandle];
        }
    }
    
    return parentTreeArray;
}

- (NSString *)mnz_fileType {
    NSDictionary *fileTypesForExtension = @{   @"3ds":@"3D Scene",
                                               @"3dm":@"3D Model",
                                               @"3fr":@"RAW Image",
                                               @"3g2":@"Multimedia",
                                               @"3gp":@"3D Model",
                                               @"7z":@"7-Zip Compressed",
                                               @"accdb":@"Database",
                                               @"aep":@"After Effects",
                                               @"aet":@"After Effects",
                                               @"ai":@"Illustrator",
                                               @"aif":@"Audio Interchange",
                                               @"aiff":@"Audio Interchange",
                                               @"ait":@"Illustrator",
                                               @"ans":@"ANSI Text File",
                                               @"apk":@"Android App",
                                               @"app":@"Mac OSX App",
                                               @"arw":@"RAW Image",
                                               @"as":@"ActionScript",
                                               @"asc":@"ActionScript Com",
                                               @"ascii":@"ASCII Text",
                                               @"asf":@"Streaming Video",
                                               @"asp":@"Active Server",
                                               @"aspx":@"Active Server",
                                               @"asx":@"Advanced Stream",
                                               @"avi":@"A/V Interleave",
                                               @"bat":@"DOS Batch",
                                               @"bay":@"Casio RAW Image",
                                               @"bmp":@"Bitmap Image",
                                               @"bz2":@"UNIX Compressed",
                                               @"c":@"C/C++ Source Code",
                                               @"cc":@"C++ Source Code",
                                               @"cdr":@"CorelDRAW Image",
                                               @"cgi":@"CGI Script",
                                               @"class":@"Java Class",
                                               @"com":@"DOS Command",
                                               @"cpp":@"C++ Source Code",
                                               @"cr2":@"Raw Image",
                                               @"css":@"CSS Style Sheet",
                                               @"cxx":@"C++ Source Code",
                                               @"dcr":@"RAW Image",
                                               @"db":@"Database",
                                               @"dbf":@"Database",
                                               @"dhtml":@"Dynamic HTML",
                                               @"dll":@"Dynamic Link Library",
                                               @"dng":@"Digital Negative",
                                               @"doc":@"MS Word",
                                               @"docx":@"MS Word",
                                               @"dotx":@"MS Word Template",
                                               @"dwg":@"Drawing DB File",
                                               @"dwt":@"Dreamweaver",
                                               @"dxf":@"DXF Image",
                                               @"eps":@"EPS Image",
                                               @"exe":@"Executable",
                                               @"fff":@"RAW Image",
                                               @"fla":@"Adobe Flash",
                                               @"flac":@"Lossless Audio",
                                               @"flv":@"Flash Video",
                                               @"fnt":@"Windows Font",
                                               @"fon":@"Font",
                                               @"gadget":@"Windows Gadget",
                                               @"gif":@"GIF Image",
                                               @"gpx":@"GPS Exchange",
                                               @"gsheet":@"Spreadsheet",
                                               @"gz":@"Gnu Compressed",
                                               @"h":@"Header",
                                               @"hpp":@"Header",
                                               @"htm":@"HTML Document",
                                               @"html":@"HTML Document",
                                               @"iff":@"Interchange",
                                               @"inc":@"Include",
                                               @"indd":@"Adobe InDesign",
                                               @"iso":@"ISO Image",
                                               @"jar":@"Java Archive",
                                               @"java":@"Java Code",
                                               @"jpeg":@"JPEG Image",
                                               @"jpg":@"JPEG Image",
                                               @"js":@"JavaScript",
                                               @"kml":@"Keyhole Markup",
                                               @"log":@"Log",
                                               @"m3u":@"Media Playlist",
                                               @"m4a":@"MPEG-4 Audio",
                                               @"max":@"3ds Max Scene",
                                               @"mdb":@"MS Access",
                                               @"mef":@"RAW Image",
                                               @"mid":@"MIDI Audio",
                                               @"midi":@"MIDI Audio",
                                               @"mkv":@"MKV Video",
                                               @"mov":@"QuickTime Movie",
                                               @"mp3":@"MP3 Audio",
                                               @"mpeg":@"MPEG Movie",
                                               @"mpg":@"MPEG Movie",
                                               @"mrw":@"Raw Image",
                                               @"msi":@"MS Installer",
                                               @"nb":@"Mathematica",
                                               @"numbers":@"Numbers",
                                               @"nef":@"RAW Image",
                                               @"obj":@"Wavefront",
                                               @"ods":@"Spreadsheet",
                                               @"odt":@"Text Document",
                                               @"otf":@"OpenType Font",
                                               @"ots":@"Spreadsheet",
                                               @"orf":@"RAW Image",
                                               @"pages":@"Pages Doc",
                                               @"pcast":@"Podcast",
                                               @"pdb":@"Database",
                                               @"pdf":@"PDF Document",
                                               @"pef":@"RAW Image",
                                               @"php":@"PHP Code",
                                               @"php3":@"PHP Code",
                                               @"php4":@"PHP Code",
                                               @"php5":@"PHP Code",
                                               @"phtml":@"PHTML Web",
                                               @"pl":@"Perl Script",
                                               @"pls":@"Audio Playlist",
                                               @"png":@"PNG Image",
                                               @"ppj":@"Adobe Premiere",
                                               @"pps":@"MS PowerPoint",
                                               @"ppt":@"MS PowerPoint",
                                               @"pptx":@"MS PowerPoint",
                                               @"prproj":@"Adobe Premiere",
                                               @"ps":@"PostScript",
                                               @"psb":@"Photoshop",
                                               @"psd":@"Photoshop",
                                               @"py":@"Python Script",
                                               @"ra":@"Real Audio",
                                               @"ram":@"Real Audio",
                                               @"rar":@"RAR Compressed",
                                               @"rm":@"Real Media",
                                               @"rtf":@"Rich Text",
                                               @"rw2":@"RAW",
                                               @"rwl":@"RAW Image",
                                               @"sh":@"Bash Shell",
                                               @"shtml":@"Server HTML",
                                               @"sitx":@"X Compressed",
                                               @"sql":@"SQL Database",
                                               @"srf":@"Sony RAW Image",
                                               @"srt":@"Subtitle",
                                               @"svg":@"Vector Image",
                                               @"svgz":@"Vector Image",
                                               @"swf":@"Flash Movie",
                                               @"tar":@"Archive",
                                               @"tbz":@"Compressed",
                                               @"tga":@"Targa Graphic",
                                               @"tgz":@"Compressed",
                                               @"tif":@"TIF Image",
                                               @"tiff":@"TIFF Image",
                                               @"torrent":@"Torrent",
                                               @"ttf":@"TrueType Font",
                                               @"txt":@"Text Document",
                                               @"vcf":@"vCard",
                                               @"wav":@"Wave Audio",
                                               @"webm":@"WebM Video",
                                               @"wma":@"WM Audio",
                                               @"wmv":@"WM Video",
                                               @"wpd":@"WordPerfect",
                                               @"wps":@"MS Works",
                                               @"xhtml":@"XHTML Web",
                                               @"xlr":@"MS Works",
                                               @"xls":@"MS Excel",
                                               @"xlsx":@"MS Excel",
                                               @"xlt":@"MS Excel",
                                               @"xltm":@"MS Excel",
                                               @"xml":@"XML Document",
                                               @"zip":@"ZIP Archive",
                                               @"mp4":@"MP4 Video"};
    
    NSString *fileType = [fileTypesForExtension objectForKey:self.name.pathExtension];
    if (fileType.length == 0) {
        fileType = [NSString stringWithFormat:@"%@ %@", self.name.pathExtension.uppercaseString, AMLocalizedString(@"file", nil).capitalizedString];
    }
    
    return fileType;
}

- (BOOL)mnz_isRestorable {
    MEGANode *restoreNode = [[MEGASdkManager sharedMEGASdk] nodeForHandle:self.restoreHandle];
    if (restoreNode && ![[MEGASdkManager sharedMEGASdk] isNodeInRubbish:restoreNode] && [[MEGASdkManager sharedMEGASdk] isNodeInRubbish:self]) {
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)mnz_isPlayable {
    BOOL supportedShortFormat = NO;
    BOOL supportedVideoCodecId = NO;
    
    // When media information is not available, try to play the node
    if (self.shortFormat == -1 && self.videoCodecId == -1) {
        return YES;
    }
    
    NSArray<NSNumber *> *shortFormats = @[@(1),
                                          @(2),
                                          @(3),
                                          @(4),
                                          @(5),
                                          @(13),
                                          @(27),
                                          @(44),
                                          @(49),
                                          @(50),
                                          @(51),
                                          @(52)];
    
    NSArray<NSNumber *> *videoCodecIds = @[@(15),
                                           @(37),
                                           @(144),
                                           @(215),
                                           @(224),
                                           @(266),
                                           @(346),
                                           @(348),
                                           @(393),
                                           @(405),
                                           @(523),
                                           @(532),
                                           @(551),
                                           @(630),
                                           @(703),
                                           @(740),
                                           @(802),
                                           @(887),
                                           @(957),
                                           @(961),
                                           @(973),
                                           @(1108),
                                           @(1114),
                                           @(1119),
                                           @(1129),
                                           @(1132),
                                           @(1177)];
    
    supportedShortFormat = [shortFormats containsObject:@(self.shortFormat)];
    supportedVideoCodecId = [videoCodecIds containsObject:@(self.videoCodecId)];
    
    return supportedShortFormat || supportedVideoCodecId;
}

- (NSString *)mnz_temporaryPathForDownloadCreatingDirectories:(BOOL)creatingDirectories {
    NSString *nodeFolderPath = [NSTemporaryDirectory() stringByAppendingPathComponent:self.base64Handle];
    NSString *nodeFilePath = [nodeFolderPath stringByAppendingPathComponent:self.name];
    
    NSError *error;
    if (creatingDirectories && ![[NSFileManager defaultManager] fileExistsAtPath:nodeFolderPath isDirectory:nil]) {
        if (![[NSFileManager defaultManager] createDirectoryAtPath:nodeFolderPath withIntermediateDirectories:YES attributes:nil error:&error]) {
            MEGALogError(@"Create directory at path failed with error: %@", error);
        }
    }
    
    return nodeFilePath;
}

#pragma mark - Versions

- (NSInteger)mnz_numberOfVersions {
    return ([[MEGASdkManager sharedMEGASdk] hasVersionsForNode:self]) ? ([[MEGASdkManager sharedMEGASdk] numberOfVersionsForNode:self]) : 0;
}


- (NSArray *)mnz_versions {
    return [[[MEGASdkManager sharedMEGASdk] versionsForNode:self] mnz_nodesArrayFromNodeList];
}

- (long long)mnz_versionsSize {
    long long totalSize = 0;
    NSArray *versions = [self mnz_versions];
    for (MEGANode *versionNode in versions) {
        totalSize += versionNode.size.longLongValue;
    }
    
    return totalSize;
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    NSString *nodeName = textField.text;
    UITextPosition *beginning = textField.beginningOfDocument;
    UITextRange *textRange;
    
    switch (self.type) {
        case MEGANodeTypeFile: {
            if ([nodeName.pathExtension isEqualToString:@""] && [nodeName isEqualToString:nodeName.stringByDeletingPathExtension]) { //File without extension
                UITextPosition *end = textField.endOfDocument;
                textRange = [textField textRangeFromPosition:beginning  toPosition:end];
            } else {
                NSRange filenameRange = [nodeName rangeOfString:@"." options:NSBackwardsSearch];
                UITextPosition *beforeExtension = [textField positionFromPosition:beginning offset:filenameRange.location];
                textRange = [textField textRangeFromPosition:beginning  toPosition:beforeExtension];
            }
            textField.selectedTextRange = textRange;
            break;
        }
            
        case MEGANodeTypeFolder: {
            UITextPosition *end = textField.endOfDocument;
            textRange = [textField textRangeFromPosition:beginning  toPosition:end];
            [textField setSelectedTextRange:textRange];
            break;
        }
            
        default:
            break;
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    BOOL shouldChangeCharacters = YES;
    switch (self.type) {
        case MEGANodeTypeFile:
        case MEGANodeTypeFolder:
            shouldChangeCharacters = YES;
            break;
            
        default:
            shouldChangeCharacters = NO;
            break;
    }
    
    return shouldChangeCharacters;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    BOOL shouldReturn = YES;
    UIAlertController *renameAlertController = (UIAlertController *)UIApplication.mnz_visibleViewController;
    if (renameAlertController) {
        UIAlertAction *rightButtonAction = renameAlertController.actions.lastObject;
        shouldReturn = rightButtonAction.enabled;
    }
    
    return shouldReturn;

}

- (void)renameAlertTextFieldDidChange:(UITextField *)textField {
    UIAlertController *renameAlertController = (UIAlertController *)UIApplication.mnz_visibleViewController;
    if (renameAlertController) {
        UIAlertAction *rightButtonAction = renameAlertController.actions.lastObject;
        BOOL enableRightButton = NO;
        
        NSString *newName = textField.text;
        NSString *nodeNameString = self.name;
        
        if (self.isFile || self.isFolder) {
            BOOL containsInvalidChars = textField.text.mnz_containsInvalidChars;
            if ([newName isEqualToString:@""] || [newName isEqualToString:nodeNameString] || newName.mnz_isEmpty || containsInvalidChars) {
                enableRightButton = NO;
            } else {
                enableRightButton = YES;
            }
            textField.textColor = containsInvalidChars ? UIColor.mnz_redMain : UIColor.darkTextColor;
        }
        
        rightButtonAction.enabled = enableRightButton;
    }
}

- (void)mnz_copyToGalleryFromTemporaryPath:(NSString *)path {
    if (self.name.mnz_isVideoPathExtension) {
        if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(path)) {
            UISaveVideoAtPathToSavedPhotosAlbum(path, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
        } else {
            [SVProgressHUD showErrorWithStatus:AMLocalizedString(@"Could not save Item", @"Text shown when an error occurs when trying to save a photo or video to Photos app")];
            MEGALogError(@"The video can be saved to the Camera Roll album");
        }
    }
    
    if (self.name.mnz_isImagePathExtension) {
        NSURL *imageURL = [NSURL fileURLWithPath:path];
        
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetCreationRequest *assetCreationRequest = [PHAssetCreationRequest creationRequestForAsset];
            [assetCreationRequest addResourceWithType:PHAssetResourceTypePhoto fileURL:imageURL options:nil];
            
        } completionHandler:^(BOOL success, NSError * _Nullable nserror) {
            [NSFileManager.defaultManager mnz_removeItemAtPath:path];
            if (nserror) {
                [SVProgressHUD showErrorWithStatus:AMLocalizedString(@"Could not save Item", @"Text shown when an error occurs when trying to save a photo or video to Photos app")];
                MEGALogError(@"Add asset to camera roll: %@ (Domain: %@ - Code:%td)", nserror.localizedDescription, nserror.domain, nserror.code);
            } else {
                [SVProgressHUD showImage:[UIImage imageNamed:@"saveToPhotos"] status:AMLocalizedString(@"Saved to Photos", @"Text shown when a photo or video is saved to Photos app")];
            }
        }];
    }
}

- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    if (error) {
        [SVProgressHUD showErrorWithStatus:AMLocalizedString(@"Could not save Item", @"Text shown when an error occurs when trying to save a photo or video to Photos app")];
        MEGALogError(@"Save video to Camera roll: %@ (Domain: %@ - Code:%td)", error.localizedDescription, error.domain, error.code);
    } else {
        [SVProgressHUD showImage:[UIImage imageNamed:@"saveToPhotos"] status:AMLocalizedString(@"Saved to Photos", @"Text shown when a photo or video is saved to Photos app")];
        [NSFileManager.defaultManager mnz_removeItemAtPath:videoPath];
    }
}

@end
