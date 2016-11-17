//
//  CreateViewController.m
//  TO-DO
//
//  Created by Siegrain on 16/5/19.
//  Copyright © 2016年 com.siegrain. All rights reserved.
//

#import "AutoLinearLayoutView.h"
#import "CreateViewController.h"
#import "DateUtil.h"
#import "GCDQueue.h"
#import "HSDatePickerViewController+Configure.h"
#import "LCTodo.h"
#import "MRTodoDataManager.h"
#import "Macros.h"
#import "NSDate+Extension.h"
#import "NSDateFormatter+Extension.h"
#import "NSNotificationCenter+Extension.h"
#import "SCLAlertHelper.h"
#import "SGCommitButton.h"
#import "SGTextField.h"
#import "UIImage+Extension.h"
#import "SGBaseMapViewController.h"
#import "SGCoordinate.h"
#import "SGImageUpload.h"
#import "GTMBase64.h"
#import "AppDelegate.h"

// FIXME: iPhone4s 上 NavigationBar 会遮挡一部分标题文本框
// TODO: 多人协作
// TODO: 为实体添加坐标字段

@interface CreateViewController () <UITextFieldDelegate>
@property(nonatomic, strong) MRTodoDataManager *dataManager;
@property(nonatomic, strong) UIView *containerView;
@property(nonatomic, strong) SGTextField *titleTextField;
@property(nonatomic, strong) AutoLinearLayoutView *linearView;
@property(nonatomic, strong) SGTextField *descriptionTextField;
@property(nonatomic, strong) SGTextField *datetimePickerField;
@property(nonatomic, strong) SGTextField *locationTextField;
@property(nonatomic, strong) SGCommitButton *commitButton;
@property(nonatomic, strong) HSDatePickerViewController *datePickerViewController;
@property(nonatomic, assign) BOOL viewIsDisappearing;

@property(nonatomic, strong) NSDate *selectedDate;
@property(nonatomic, assign) CGFloat fieldHeight;
@property(nonatomic, assign) CGFloat fieldSpacing;
@property(nonatomic, strong) UIImage *selectedImage;
@property(nonatomic, strong) SGCoordinate *selectedCoordinate;
@end

@implementation CreateViewController
#pragma mark - localization

- (void)localizeStrings {
    self.titleLabel.text = Localized(@"Create New");
    _descriptionTextField.label.text = Localized(@"Description");
    _datetimePickerField.label.text = Localized(@"Time");
    _locationTextField.label.text = Localized(@"Location");
    [_commitButton.button setTitle:Localized(@"DONE") forState:UIControlStateNormal];
    _titleTextField.field.attributedPlaceholder = [[NSAttributedString alloc] initWithString:Localized(@"Title") attributes:@{NSForegroundColorAttributeName: ColorWithRGB(0xCCCCCC), NSFontAttributeName: _titleTextField.field.font}];
}

#pragma mark - initial

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self localizeStrings];
    [_titleTextField becomeFirstResponder];
}

- (void)setupViews {
    [super setupViews];
    
    _fieldHeight = kScreenHeight * 0.08;
    _fieldSpacing = kScreenHeight * 0.03;
    [NSNotificationCenter attachKeyboardObservers:self keyboardWillShowSelector:@selector(keyboardWillShow:) keyboardWillHideSelector:@selector(keyboardWillHide:)];
    
    _dataManager = [MRTodoDataManager new];
    
    _datePickerViewController = [[HSDatePickerViewController alloc] init];
    [_datePickerViewController configure];
    _datePickerViewController.delegate = self;
    
    __weak typeof(self) weakSelf = self;
    // Mark: 需要这个的原因是 self.view 在视图加载时还不在窗口层级中，无法为其绑定约束
    _containerView = [UIView new];
    _containerView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:_containerView];
    
    self.headerView = [SGHeaderView headerViewWithAvatarPosition:HeaderAvatarPositionCenter titleAlignement:HeaderTitleAlignmentCenter];
    [self.headerView setImage:[UIImage imageAtResourcePath:@"create header bg"] style:HeaderMaskStyleDark];
    [self.headerView.rightOperationButton setImage:[UIImage imageNamed:@"photo"] forState:UIControlStateNormal];
    [self.headerView setHeaderViewDidPressRightOperationButton:^{[weakSelf headerViewDidPressRightOperationButton];}];
    self.headerView.avatarButton.hidden = YES;
    [_containerView addSubview:self.headerView];
    
    _titleTextField = [SGTextField textField];
    _titleTextField.field.font = [SGHelper themeFontWithSize:32];
    _titleTextField.field.textColor = [UIColor whiteColor];
    _titleTextField.field.returnKeyType = UIReturnKeyNext;
    _titleTextField.isUnderlineHidden = YES;
    [_titleTextField setTextFieldShouldReturn:^(SGTextField *textField) {
        [textField resignFirstResponder];
        [weakSelf showDatetimePicker];
    }];
    [self.headerView addSubview:_titleTextField];
    
    _linearView = [[AutoLinearLayoutView alloc] init];
    _linearView.axisVertical = YES;
    _linearView.spacing = _fieldSpacing;
    [_containerView addSubview:_linearView];
    
    _datetimePickerField = [SGTextField textField];
    _datetimePickerField.field.returnKeyType = UIReturnKeyNext;
    _datetimePickerField.enabled = NO;
    [_datetimePickerField addTarget:self action:@selector(showDatetimePicker) forControlEvents:UIControlEventTouchUpInside];
    [_linearView addSubview:_datetimePickerField];
    
    _descriptionTextField = [SGTextField textField];
    _descriptionTextField.field.returnKeyType = UIReturnKeyNext;
    [_descriptionTextField setTextFieldShouldReturn:^(SGTextField *textField) {
        __strong typeof(self) strongSelf = weakSelf;
        [strongSelf->_locationTextField becomeFirstResponder];
    }];
    [_linearView addSubview:_descriptionTextField];
    
    _locationTextField = [SGTextField textField];
    _locationTextField.field.returnKeyType = UIReturnKeyDone;
    _locationTextField.field.delegate = self;
    [_locationTextField setTextFieldShouldReturn:^(SGTextField *textField) {[weakSelf commitButtonDidPress];}];
    [_linearView addSubview:_locationTextField];
    
    _commitButton = [SGCommitButton commitButton];
    [_commitButton setCommitButtonDidPress:^{[weakSelf commitButtonDidPress];}];
    [_containerView addSubview:_commitButton];
}

- (void)bindConstraints {
    [super bindConstraints];
    
    [_containerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.right.bottom.offset(0);
    }];
    
    [self.headerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.offset(0);
        make.width.offset(kScreenWidth);
        make.height.offset(kScreenHeight * 0.3);
    }];
    
    [_titleTextField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.offset(0);
        make.centerY.offset(-10);
        make.height.offset(40);
    }];
    
    [_linearView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.offset(20);
        make.right.offset(-20);
        make.top.equalTo(self.headerView.mas_bottom).offset(20);
        make.height.offset((_fieldHeight + _fieldSpacing) * 3);
    }];
    
    [@[_descriptionTextField, _datetimePickerField, _locationTextField] mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.offset(0);
        make.height.offset(_fieldHeight);
    }];
    
    [_commitButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(_linearView);
        make.height.offset(_fieldHeight);
        make.bottom.offset(-20);
    }];
}

#pragma mark - commit

- (void)commitButtonDidPress {
    __weak typeof(self) weakSelf = self;
    
    [[GCDQueue globalQueueWithLevel:DISPATCH_QUEUE_PRIORITY_DEFAULT] sync:^{
        if (weakSelf.commitButton.indicator.isAnimating) return;
        
        [weakSelf.view endEditing:YES];
        [weakSelf enableView:NO];
        
        CDTodo *todo = [CDTodo MR_createEntity];
        todo.title = weakSelf.titleTextField.field.text;
        todo.sgDescription = weakSelf.descriptionTextField.field.text;
        todo.deadline = self.selectedDate;
        todo.user = weakSelf.cdUser;
        todo.status = @(TodoStatusNormal);
        todo.isCompleted = @(NO);
        todo.isHidden = @(NO);
        todo.createdAt = [NSDate date];
        todo.updatedAt = [todo.createdAt copy];
        todo.identifier = [[NSUUID UUID] UUIDString];
        if (_selectedCoordinate) {
            todo.longitude = @(_selectedCoordinate.longitude);
            todo.latitude = @(_selectedCoordinate.latitude);
            todo.generalAddress = _selectedCoordinate.generalAddress;
            todo.explicitAddress = _selectedCoordinate.explicitAddress;
        }
        if (_selectedImage) {
            NSData *imageData = [SGImageUpload dataWithImage:_selectedImage type:SGImageTypePhoto quality:kSGDefaultImageQuality];
            todo.photoData = imageData;
            todo.photoImage = [UIImage imageWithData:imageData];
        }
        
        [weakSelf enableView:YES];
        if (![weakSelf.dataManager isInsertedTodo:todo]) return;
        if (weakSelf.createViewControllerDidFinishCreate) weakSelf.createViewControllerDidFinishCreate(todo);
        [weakSelf.navigationController popToRootViewControllerAnimated:YES];
    }];
}

- (void)enableView:(BOOL)isEnable {
    [_commitButton setAnimating:!isEnable];
    self.headerView.userInteractionEnabled = isEnable;
}

#pragma mark - pick picture

- (void)headerViewDidPressRightOperationButton {
    [SGHelper photoPickerFromTarget:self];
}

#pragma mark - imagePicker delegate

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary<NSString *, id> *)info {
    _selectedImage = info[UIImagePickerControllerEditedImage];
    [self.headerView.rightOperationButton setImage:_selectedImage forState:UIControlStateNormal];
    [picker dismissViewControllerAnimated:true completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:true completion:nil];
}

#pragma mark - keyboard events & animation

- (void)keyboardWillShow:(NSNotification *)notification {
    [self animateByKeyboard:YES];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    [self animateByKeyboard:NO];
}

- (void)animateByKeyboard:(BOOL)isShowAnimation {
    // Mark: 视图在 Disappear 之后再 Appear 时，会恢复键盘状态，但是这时不会知道是哪个控件的焦点，所以必须再判断一下
    if (_titleTextField.field.isFirstResponder || _viewIsDisappearing) return;
    
    [_containerView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.top.bottom.offset(isShowAnimation ? -115 : 0);
    }];
    [_commitButton mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(_linearView);
        make.height.offset(_fieldHeight);
        if (isShowAnimation)
            make.top.equalTo(_locationTextField.mas_bottom).offset(20);
        else
            make.bottom.offset(-20);
    }];
    
    [UIView animateWithDuration:1 animations:^{
        [_containerView.superview layoutIfNeeded];
        [self.navigationController.navigationBar setHidden:isShowAnimation];
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    _viewIsDisappearing = NO;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    _viewIsDisappearing = YES;
    [self.view endEditing:YES];
}

#pragma mark - datetime picker

- (void)showDatetimePicker {
    if (_selectedDate) _datePickerViewController.date = _selectedDate;
    [self presentViewController:_datePickerViewController animated:YES completion:nil];
}

- (BOOL)hsDatePickerPickedDate:(NSDate *)date {
    if ([date timeIntervalSince1970] < [_datePickerViewController.minDate timeIntervalSince1970])
        date = [NSDate date];
    
    _selectedDate = date;
    _datetimePickerField.field.text = [DateUtil dateString:date withFormat:@"yyyy.MM.dd HH:mm"];
    
    return true;
}

#pragma mark - text field

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    if (textField == _locationTextField.field) {
        SGBaseMapViewController *viewController = [SGBaseMapViewController new];
        viewController.coordinate = self.selectedCoordinate;
        __weak __typeof(self) weakSelf = self;
        [viewController setBlock:^(SGCoordinate *coordinate) {
            weakSelf.selectedCoordinate = coordinate;
            weakSelf.locationTextField.field.text = coordinate.explicitAddress;
        }];
        
        [self.navigationController pushViewController:viewController animated:YES];
        
        return NO;
    }
    return YES;
}

- (void)dealloc {
    NSLog(@"%s", __func__);
}
@end
