#import "../ios/GameStorage.h"
#include <cassert>

int main(int argc,char **argv) {
    @autoreleasepool {
        assert(argc==2);
        NSString *root=[[NSString stringWithUTF8String:argv[1]] stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        NSFileManager *fm=NSFileManager.defaultManager;
        NSArray *paths=@[@"Games/a.jar",@"Games/a.jar.title",@"Games/b.jar",@"Saves/a/store",@"Saves/b/store",@"Files/shared",@"Saves/builtin-demo/store"];
        for(NSString *relative in paths) {
            NSString *path=[root stringByAppendingPathComponent:relative];
            assert([fm createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil]);
            assert([@"test data" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]);
        }
        NSError *error=nil;
        assert(!NJClearGameData(root,@"../b",&error));
        assert([fm fileExistsAtPath:[root stringByAppendingPathComponent:@"Saves/b/store"]]);
        assert(NJClearGameData(root,@"a",&error));
        assert(![fm fileExistsAtPath:[root stringByAppendingPathComponent:@"Saves/a"]]);
        assert([fm fileExistsAtPath:[root stringByAppendingPathComponent:@"Games/a.jar"]]);
        assert(NJDeleteImportedGame(root,@"a.jar",&error));
        assert(![fm fileExistsAtPath:[root stringByAppendingPathComponent:@"Games/a.jar"]]);
        assert(![fm fileExistsAtPath:[root stringByAppendingPathComponent:@"Games/a.jar.title"]]);
        assert([fm fileExistsAtPath:[root stringByAppendingPathComponent:@"Games/b.jar"]]);
        assert([fm fileExistsAtPath:[root stringByAppendingPathComponent:@"Saves/b/store"]]);
        assert([fm fileExistsAtPath:[root stringByAppendingPathComponent:@"Files/shared"]]);
        assert(NJClearGameData(root,@"builtin-demo",&error));
        assert(![fm fileExistsAtPath:[root stringByAppendingPathComponent:@"Saves/builtin-demo"]]);
        assert(!NJDeleteImportedGame(root,@"../b.jar",&error));
        assert(!NJDeleteImportedGame(root,@"..\\b.jar",&error));
        assert(!NJDeleteImportedGame(root,@"Saves",&error));
        assert(NJDeleteImportedGame(root,@"missing.jar",&error));
        assert([fm removeItemAtPath:root error:nil]);
        puts("Game storage isolation and deletion checks passed.");
    }
}
