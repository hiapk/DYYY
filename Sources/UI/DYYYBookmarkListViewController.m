#import "DYYYBookmarkListViewController.h"
#import "AwemeHeaders.h"
#import "DYYYBookmarkRecord.h"
#import "DYYYCustomInputView.h"
#import "DYYYLocalRecordStore.h"
#import "DYYYLocalTools.h"
#import "DYYYUtils.h"

@interface DYYYBookmarkListViewController () <UISearchResultsUpdating>
@property(nonatomic, copy) NSString *account;
@property(nonatomic, copy) NSArray<NSDictionary *> *records;
@property(nonatomic, copy) NSArray<NSDictionary *> *filteredRecords;
@property(nonatomic, strong) DYYYLocalRecordStore *store;
@property(nonatomic, strong) UISearchController *search;
@property(nonatomic, assign) NSUInteger loadGeneration;
@end

@implementation DYYYBookmarkListViewController

- (instancetype)initWithAccount:(NSString *)account {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _account = [account copy];
        _store = [DYYYLocalTools recordStoreWithName:@"bookmarks" account:account];
        _records = @[];
        _filteredRecords = @[];
    }
    return self;
}

- (BOOL)accountMatches {
    return [self.account isEqual:([DYYYUtils currentAccountID] ?: @"guest")];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"本地书签";
    self.view.backgroundColor = [DYYYUtils douyinPanelBackgroundColor];
    self.tableView.backgroundColor = self.view.backgroundColor;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];
    self.search = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.search.searchResultsUpdater = self;
    self.search.obscuresBackgroundDuringPresentation = NO;
    self.search.searchBar.placeholder = @"搜索标题、作者、分类、备注或 UID";
    self.navigationItem.searchController = self.search;
    self.definesPresentationContext = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadRecords];
}

- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }

- (void)reloadRecords {
    NSUInteger generation = ++self.loadGeneration;
    if (![self accountMatches]) {
        self.records = @[];
        [self updateSearchResultsForSearchController:self.search];
        [DYYYUtils showToast:@"账号已切换，请重新打开书签列表"];
        return;
    }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error;
        NSArray *all = [self.store recordsWithError:&error];
        NSMutableArray *valid = [NSMutableArray array];
        for (NSDictionary *record in all) if ([DYYYBookmarkRecord routeForRecord:record]) [valid addObject:record];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation != self.loadGeneration || ![self accountMatches]) return;
            self.records = valid;
            [self updateSearchResultsForSearchController:self.search];
            if (error) [DYYYUtils showToast:error.localizedDescription];
        });
    });
}

+ (NSString *)text:(id)value { return [value isKindOfClass:NSString.class] ? value : @""; }

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *query = [searchController.searchBar.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSMutableArray *matches = [NSMutableArray array];
    for (NSDictionary *record in self.records) {
        NSMutableArray *fields = [NSMutableArray array];
        for (NSString *key in @[@"title", @"author", @"category", @"note", @"identifier"]) [fields addObject:[self.class text:record[key]]];
        if (!query.length || [[fields componentsJoinedByString:@" "] localizedCaseInsensitiveContainsString:query]) [matches addObject:record];
    }
    self.filteredRecords = matches;
    UILabel *empty = [UILabel new];
    empty.text = query.length ? @"没有匹配的书签" : @"长按视频或在主页菜单添加书签\n左滑可修改分类、备注或删除\n书签仅保存在本机，按抖音账号隔离";
    empty.numberOfLines = 0;
    empty.textAlignment = NSTextAlignmentCenter;
    empty.textColor = UIColor.secondaryLabelColor;
    empty.font = [UIFont systemFontOfSize:14];
    self.tableView.backgroundView = matches.count ? nil : empty;
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.filteredRecords.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"bookmark"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"bookmark"];
    NSDictionary *record = self.filteredRecords[indexPath.row];
    NSString *type = [record[@"type"] isEqual:@"profile"] ? @"主页" : @"视频";
    NSString *title = [self.class text:record[@"title"]];
    NSString *category = [self.class text:record[@"category"]];
    cell.textLabel.text = [NSString stringWithFormat:@"[%@] %@", type, title.length ? title : record[@"identifier"]];
    cell.textLabel.numberOfLines = 2;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@\n%@", category.length ? category : @"未分类", [self.class text:record[@"author"]], [self.class text:record[@"note"]]];
    cell.detailTextLabel.numberOfLines = 3;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (![self accountMatches]) { [self reloadRecords]; return; }
    NSString *route = [DYYYBookmarkRecord routeForRecord:self.filteredRecords[indexPath.row]];
    Class router = NSClassFromString(@"AWERouter");
    if (!route || ![router respondsToSelector:@selector(canOpenURLString:)] || ![router respondsToSelector:@selector(transferToURLString:)] || ![router canOpenURLString:route]) {
        [DYYYUtils showToast:@"当前抖音版本无法打开该书签"];
        return;
    }
    [self dismissViewControllerAnimated:YES completion:^{
        if (![router transferToURLString:route]) [DYYYUtils showToast:@"内容无法打开，可能已删除或不可见"];
    }];
}

- (void)writeRecord:(NSDictionary *)record deleting:(BOOL)deleting {
    if (![self accountMatches]) { [self reloadRecords]; return; }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error;
        BOOL success = [self.store updateRecords:^NSArray *(NSArray *records, NSError **failure) {
            if (!deleting) return [DYYYBookmarkRecord recordsByUpserting:record intoRecords:records];
            NSMutableArray *remaining = [NSMutableArray array];
            for (NSDictionary *item in records) if (![item[@"id"] isEqual:record[@"id"]]) [remaining addObject:item];
            return remaining;
        } error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!success) [DYYYUtils showToast:error.localizedDescription ?: @"书签更新失败"];
            [self reloadRecords];
        });
    });
}

- (void)editRecord:(NSDictionary *)record {
    DYYYCustomInputView *category = [[DYYYCustomInputView alloc] initWithTitle:@"书签分类（最多 30 字）" defaultText:[self.class text:record[@"category"]] placeholder:@"留空为未分类"];
    __weak typeof(self) weakSelf = self;
    category.onConfirm = ^(NSString *value) {
        if (!weakSelf || ![weakSelf accountMatches]) return;
        NSString *categoryText = value.length > 30 ? [value substringToIndex:30] : value;
        DYYYCustomInputView *note = [[DYYYCustomInputView alloc] initWithTitle:@"书签备注（最多 500 字）" defaultText:[self.class text:record[@"note"]] placeholder:@"输入备注"];
        note.onConfirm = ^(NSString *text) {
            NSMutableDictionary *updated = [record mutableCopy];
            updated[@"category"] = categoryText;
            updated[@"note"] = text.length > 500 ? [text substringToIndex:500] : text;
            [weakSelf writeRecord:updated deleting:NO];
        };
        [note show];
    };
    [category show];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *record = self.filteredRecords[indexPath.row];
    __weak typeof(self) weakSelf = self;
    UIContextualAction *edit = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"编辑" handler:^(UIContextualAction *action, UIView *view, void (^completion)(BOOL)) {
        completion(YES);
        [weakSelf editRecord:record];
    }];
    UIContextualAction *remove = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"删除" handler:^(UIContextualAction *action, UIView *view, void (^completion)(BOOL)) {
        completion(YES);
        [weakSelf writeRecord:record deleting:YES];
    }];
    UISwipeActionsConfiguration *configuration = [UISwipeActionsConfiguration configurationWithActions:@[remove, edit]];
    configuration.performsFirstActionWithFullSwipe = NO;
    return configuration;
}
@end
