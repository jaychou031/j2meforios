#import "GameStorage.h"

static BOOL safeName(NSString *name) {
    return name.length && ![name isEqualToString:@"."] && ![name isEqualToString:@".."] &&
        [name rangeOfString:@"/"].location==NSNotFound &&
        [name rangeOfString:@"\\"].location==NSNotFound;
}
static BOOL invalidName(NSError **error) {
    if(error) *error=[NSError errorWithDomain:@"J2MEStorage" code:1 userInfo:@{NSLocalizedDescriptionKey:@"无效的游戏文件名，未执行删除。"}];
    return NO;
}
NSString *NJGameRMSPath(NSString *root, NSString *gameID) {
    return safeName(gameID)?[[root stringByAppendingPathComponent:@"Saves"] stringByAppendingPathComponent:gameID]:nil;
}
static BOOL removeIfPresent(NSString *path, NSError **error) {
    NSFileManager *fm=NSFileManager.defaultManager;
    if(![fm fileExistsAtPath:path]) return YES;
    return [fm removeItemAtPath:path error:error];
}
BOOL NJClearGameData(NSString *root, NSString *gameID, NSError **error) {
    if(!safeName(gameID)) return invalidName(error);
    // The old Files directory was shared. It has no reliable ownership
    // information, so clearing one game must never erase that directory.
    return removeIfPresent(NJGameRMSPath(root,gameID),error);
}
BOOL NJDeleteImportedGame(NSString *root, NSString *filename, NSError **error) {
    if(!safeName(filename) || ![filename.pathExtension.lowercaseString isEqualToString:@"jar"] ||
       !safeName(filename.stringByDeletingPathExtension)) return invalidName(error);
    if(!NJClearGameData(root,filename.stringByDeletingPathExtension,error)) return NO;
    NSString *jar=[[root stringByAppendingPathComponent:@"Games"] stringByAppendingPathComponent:filename];
    if(!removeIfPresent(jar,error)) return NO;
    return removeIfPresent([jar stringByAppendingString:@".title"],error);
}
