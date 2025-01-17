
#import "FileManagementTableViewController.h"

#import "SVProgressHUD.h"

#import "Helper.h"
#import "MEGAReachabilityManager.h"
#import "MEGASdkManager.h"
#import "MEGASdk+MNZCategory.h"
#import "MEGAStore.h"
#import "NSFileManager+MNZCategory.h"
#import "NSString+MNZCategory.h"

@interface FileManagementTableViewController () <MEGAGlobalDelegate, MEGARequestDelegate>

@property (weak, nonatomic) IBOutlet UILabel *clearOfflineFilesLabel;
@property (weak, nonatomic) IBOutlet UILabel *clearCacheLabel;

@property (weak, nonatomic) IBOutlet UILabel *rubbishBinLabel;

@property (weak, nonatomic) IBOutlet UILabel *fileVersioningLabel;
@property (weak, nonatomic) IBOutlet UISwitch *fileVersioningSwitch;

@property (weak, nonatomic) IBOutlet UILabel *fileVersionsLabel;
@property (weak, nonatomic) IBOutlet UILabel *fileVersionsDetailLabel;

@property (weak, nonatomic) IBOutlet UILabel *deleteOldVersionsLabel;

@property (nonatomic, copy) NSString *offlineSizeString;
@property (nonatomic, copy) NSString *cacheSizeString;

@property (nonatomic, getter=isFileVersioningEnabled) BOOL fileVersioningEnabled;

@end

@implementation FileManagementTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = AMLocalizedString(@"File Management", @"A section header which contains the file management settings. These settings allow users to remove duplicate files etc.");
    
    _offlineSizeString = @"...";
    _cacheSizeString = @"...";
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.clearOfflineFilesLabel.text = AMLocalizedString(@"clearOfflineFiles", @"Section title where you can 'Clear Offline files' of your MEGA app");
    self.clearCacheLabel.text = AMLocalizedString(@"clearCache", @"Section title where you can 'Clear Cache' of your MEGA app");
    
    self.rubbishBinLabel.text = AMLocalizedString(@"rubbishBinLabel", @"Title of one of the Settings sections where you can see your MEGA 'Rubbish Bin'");
    
    self.fileVersioningLabel.text = AMLocalizedString(@"File versioning", @"Title of the option to enable or disable file versioning on Settings section");
    [[MEGASdkManager sharedMEGASdk] getFileVersionsOptionWithDelegate:self];
    
    self.fileVersionsLabel.text = AMLocalizedString(@"File versions", @"Settings preference title to show file versions info of the account");
    long long totalNumberOfVersions = [[[MEGASdkManager sharedMEGASdk] mnz_accountDetails] numberOfVersionFilesForHandle:[[[MEGASdkManager sharedMEGASdk] rootNode] handle]];
    self.fileVersionsDetailLabel.text = [NSString stringWithFormat:@"%lld", totalNumberOfVersions];
    
    self.deleteOldVersionsLabel.text = AMLocalizedString(@"Delete previous versions", @"Text of a button which deletes all historical versions of files in the users entire account.");
    
    [[MEGASdkManager sharedMEGASdk] addMEGAGlobalDelegate:self];
    
    [self reloadUI];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[MEGASdkManager sharedMEGASdk] removeMEGAGlobalDelegate:self];
}

- (void)reloadUI {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        unsigned long long offlineSize = [Helper sizeOfFolderAtPath:[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]];
        self.offlineSizeString = [Helper memoryStyleStringFromByteCount:offlineSize];
        self.offlineSizeString = [self formatStringFromByteCountFormatter:self.offlineSizeString];
        
        unsigned long long thumbnailsSize = [Helper sizeOfFolderAtPath:[Helper pathForSharedSandboxCacheDirectory:@"thumbnailsV3"]];
        unsigned long long previewsSize = [Helper sizeOfFolderAtPath:[[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"previewsV3"]];
        unsigned long long temporaryDirectory = [Helper sizeOfFolderAtPath:NSTemporaryDirectory()];
        unsigned long long cacheSize = thumbnailsSize + previewsSize + temporaryDirectory;
        
        self.cacheSizeString = [Helper memoryStyleStringFromByteCount:cacheSize];
        self.cacheSizeString = [self formatStringFromByteCountFormatter:self.cacheSizeString];
        
        dispatch_async(dispatch_get_main_queue(), ^(void){
            [self.tableView reloadData];
        });
    });
    
}

#pragma mark - Private

- (NSString *)formatStringFromByteCountFormatter:(NSString *)stringFromByteCount {
    NSArray *componentsSeparatedByStringArray = [stringFromByteCount componentsSeparatedByString:@" "];
    NSString *countString = [NSString mnz_stringWithoutUnitOfComponents:componentsSeparatedByStringArray];
    NSString *unitString = [NSString mnz_stringWithoutCountOfComponents:componentsSeparatedByStringArray];
    
    return [NSString stringWithFormat:@"%@ %@", countString, unitString];
}

#pragma mark - IBActions

- (IBAction)fileVersioningSwitchTouchUpInside:(UIButton *)sender {
    if (self.fileVersioningSwitch.isOn) {
        UIAlertController *enableOrDisableFileVersioningAlertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"When file versioning is disabled, the current version will be replaced with the new version once a file is updated (and your changes to the file will no longer be recorded). Are you sure you want to disable file versioning?", @"A confirmation message when the user chooses to disable file versioning.") message:nil preferredStyle:UIAlertControllerStyleAlert];
        [enableOrDisableFileVersioningAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"no", nil) style:UIAlertActionStyleCancel handler:nil]];
        [enableOrDisableFileVersioningAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"yes", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            if ([MEGAReachabilityManager isReachableHUDIfNot]) {
                [[MEGASdkManager sharedMEGASdk] setFileVersionsOption:YES delegate:self];
            }
        }]];
        
        [self presentViewController:enableOrDisableFileVersioningAlertController animated:YES completion:nil];
    } else {
        if ([MEGAReachabilityManager isReachableHUDIfNot]) {
            [[MEGASdkManager sharedMEGASdk] setFileVersionsOption:NO delegate:self];
        }
    }
}

#pragma mark - UITableViewDataSource

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *titleHeader;
    switch (section) {
        case 0: //On your device
            titleHeader = AMLocalizedString(@"onYourDevice", @"Title header that refers to where do you do the actions 'Clear Offlines files' and 'Clear cache' inside 'Settings' -> 'Advanced' section");
            break;
            
        case 2: //On MEGA
            titleHeader = AMLocalizedString(@"onMEGA", @"Title header that refers to where do you do the action 'Empty Rubbish Bin' inside 'Settings' -> 'Advanced' section");
            break;
            
        case 3: //File Versioning
            titleHeader = AMLocalizedString(@"File versioning", @"Title of the option to enable or disable file versioning on Settings section");
            break;
            
        case 5: //Delete all my older versions of files
            titleHeader = AMLocalizedString(@"Delete all older versions of my files", @"The title of the section about deleting file versions in the settings.");
            break;
    }
    
    return titleHeader;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    NSString *titleFooter;
    switch (section) {
        case 0: { //On your device - Offline
            NSString *currentlyUsingString = AMLocalizedString(@"currentlyUsing", @"Footer text that explain what amount of space you will free up if 'Clear Offline data', 'Clear cache' or 'Clear Rubbish Bin' is tapped");
            currentlyUsingString = [currentlyUsingString stringByReplacingOccurrencesOfString:@"%s" withString:self.offlineSizeString];
            titleFooter = currentlyUsingString;
            break;
        }
            
        case 1: { //On your device - Clear cache
            NSString *currentlyUsingString = AMLocalizedString(@"currentlyUsing", @"Footer text that explain what amount of space you will free up if 'Clear Offline data', 'Clear cache' or 'Clear Rubbish Bin' is tapped");
            currentlyUsingString = [currentlyUsingString stringByReplacingOccurrencesOfString:@"%s" withString:self.cacheSizeString];
            titleFooter = currentlyUsingString;
            break;
        }
            
        case 2: { //On MEGA - Rubbish Bin
            NSNumber *rubbishBinSizeNumber = [[MEGASdkManager sharedMEGASdk] sizeForNode:[[MEGASdkManager sharedMEGASdk] rubbishNode]];
            NSString *stringFromByteCount = [Helper memoryStyleStringFromByteCount:rubbishBinSizeNumber.unsignedLongLongValue];
            stringFromByteCount = [self formatStringFromByteCountFormatter:stringFromByteCount];
            NSString *currentlyUsingString = AMLocalizedString(@"currentlyUsing", @"Footer text that explain what amount of space you will free up if 'Clear Offline data', 'Clear cache' or 'Clear Rubbish Bin' is tapped");
            currentlyUsingString = [currentlyUsingString stringByReplacingOccurrencesOfString:@"%s" withString:stringFromByteCount];
            titleFooter = currentlyUsingString;
            break;
        }
            
        case 3: { //File Versioning - File Versioning
            NSString *fileVersioningDescription = AMLocalizedString(@"Enable or disable file versioning for your entire account.[Br]You may still receive file versions from shared folders if your contacts have this enabled.", @"Subtitle of the option to enable or disable file versioning on Settings section");
            titleFooter = [fileVersioningDescription stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
            break;
        }
            
        case 4: { //File Versioning - File Versions
            long long totalNumberOfVersionsSize = [[[MEGASdkManager sharedMEGASdk] mnz_accountDetails] versionStorageUsedForHandle:[[[MEGASdkManager sharedMEGASdk] rootNode] handle]];
            NSString *stringFromByteCount = [Helper memoryStyleStringFromByteCount:totalNumberOfVersionsSize];
            stringFromByteCount = [self formatStringFromByteCountFormatter:stringFromByteCount];
            NSString *totalFileVersionsSize = [NSString stringWithFormat:@"%@ %@", AMLocalizedString(@"Total size taken up by file versions:", @"A title message in the user’s account settings for showing the storage used for file versions."), stringFromByteCount];
            titleFooter = totalFileVersionsSize;
            break;
        }
            
        case 5: { //File Versioning - Delete Old Versions
            titleFooter = AMLocalizedString(@"All current files will remain. Only historic versions of your files will be deleted.", @"A warning note about deleting all file versions in the settings section.");
            break;
        }
    }
    
    return titleFooter;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case 0: { //On your device - Offline
            NSString *offlinePathString = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
            [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeClear];
            [SVProgressHUD show];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
                [NSFileManager.defaultManager mnz_removeFolderContentsAtPath:offlinePathString];
                dispatch_async(dispatch_get_main_queue(), ^(void){
                    [SVProgressHUD dismiss];
                    [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeNone];
                    [[MEGAStore shareInstance] removeAllOfflineNodes];
                    [self reloadUI];
                });
            });
            break;
        }
            
        case 1: { //On your device - Clear cache
            NSString *thumbnailsPathString = [Helper pathForSharedSandboxCacheDirectory:@"thumbnailsV3"];
            NSString *previewsPathString = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"previewsV3"];
            
            [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeClear];
            [SVProgressHUD show];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
                [NSFileManager.defaultManager mnz_removeFolderContentsAtPath:thumbnailsPathString];
                [NSFileManager.defaultManager mnz_removeFolderContentsAtPath:previewsPathString];
                [NSFileManager.defaultManager mnz_removeFolderContentsAtPath:NSTemporaryDirectory()];
                dispatch_async(dispatch_get_main_queue(), ^(void){
                    [SVProgressHUD dismiss];
                    [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeNone];
                    [self reloadUI];
                });
            });
            break;
        }
            
        case 2: //On MEGA - Rubbish Bin
        case 3: //File Versioning - File Versioning
        case 4: //File Versioning - File Versions
            break;
            
        case 5: { //File Versioning - Delete all file versions
            NSString *alertMessage = AMLocalizedString(@"You are about to delete the version histories of all files. Any file version shared to you from a contact will need to be deleted by them.[Br][Br]Please note that the current files will not be deleted.", @"Text of the dialog to delete all the file versions of the account");
            alertMessage = [alertMessage stringByReplacingOccurrencesOfString:@"\n\n" withString:@"\n"];
            
            UIAlertController *deleteAllFileVersionsAlertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"Delete all older versions of my files", @"The title of the section about deleting file versions in the settings.") message:alertMessage preferredStyle:UIAlertControllerStyleAlert];
            [deleteAllFileVersionsAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"no", nil) style:UIAlertActionStyleCancel handler:nil]];
            [deleteAllFileVersionsAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"yes", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                if ([MEGAReachabilityManager isReachableHUDIfNot]) {
                    [[MEGASdkManager sharedMEGASdk] removeVersions];
                }
            }]];
            
            [self presentViewController:deleteAllFileVersionsAlertController animated:YES completion:nil];
            break;
        }
            
        default:
            break;
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - MEGAGlobalDelegate

- (void)onNodesUpdate:(MEGASdk *)api nodeList:(MEGANodeList *)nodeList {
    [self.tableView reloadData];
}

- (void)onUsersUpdate:(MEGASdk *)api userList:(MEGAUserList *)userList {
    NSInteger userListCount = userList.size.integerValue;
    for (NSInteger i = 0 ; i < userListCount; i++) {
        MEGAUser *user = [userList userAtIndex:i];
        
        if (user.handle == api.myUser.handle && [user hasChangedType:MEGAUserChangeTypeDisableVersions] && user.isOwnChange == 0) {
            [api getFileVersionsOptionWithDelegate:self];
        }
    }
}

#pragma mark - MEGARequestDelegate

- (void)onRequestFinish:(MEGASdk *)api request:(MEGARequest *)request error:(MEGAError *)error {
    if ((request.type == MEGARequestTypeGetAttrUser) && (request.paramType == MEGAUserAttributeDisableVersions)) {
        if (!error.type || error.type == MEGAErrorTypeApiENoent) {
            self.fileVersioningSwitch.on = self.fileVersioningEnabled = !request.flag;
            
            [self.tableView reloadData];
        }
    }
    
    if ((request.type == MEGARequestTypeSetAttrUser) && (request.paramType == MEGAUserAttributeDisableVersions)) {
        if (!error.type) {
            self.fileVersioningSwitch.on = self.fileVersioningEnabled = ![request.text isEqualToString:@"1"];
            
            [self.tableView reloadData];
        }
    }
}

@end
