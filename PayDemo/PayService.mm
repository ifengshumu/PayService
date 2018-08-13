//
//  PayService.m
//  PayDemo
//
//  Created by 李志华 on 2018/8/9.
//  Copyright © 2018年 Chris Lee. All rights reserved.
//

#import "PayService.h"
#import <AlipaySDK/AlipaySDK.h>

#import "WXpaySDK/WXApi.h"
#import "WXpaySDK/WXApiObject.h"

#import "UnionPaySDK/UPPaymentControl.h"

#import <AddressBook/AddressBook.h>

@interface PayService ()<WXApiDelegate, PKPaymentAuthorizationViewControllerDelegate>
@property (nonatomic, copy) void(^payResult)(BOOL success, NSString *data);
@property (nonatomic, copy) NSString *payState;//判断回调是否运行,end:是，start：否
@property (nonatomic, strong) UIViewController *viewController;
@end

static PayService *service = nil;
@implementation PayService

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (instancetype)defaultService {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        service = [[PayService alloc] init];
    });
    return service;
}

- (instancetype)init {
    if (self = [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(registerAppForWX) name:UIApplicationDidFinishLaunchingNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enterForegroundNotification:) name:UIApplicationWillEnterForegroundNotification object:nil];
    }
    return self;
}

+ (BOOL)isSupportWXPay {
    return [WXApi isWXAppInstalled] && [WXApi isWXAppSupportApi];
}

+ (void)registerAppForWX:(NSString *)appID {
    BOOL success = [WXApi registerApp:appID];
    NSAssert(success, @"微信注册失败");
}

+ (BOOL)isSupportApplePay {
    return [PKPaymentAuthorizationViewController class] && [PKPaymentAuthorizationViewController canMakePayments];
}

+ (BOOL)isApplePaySupportBankCards:(NSArray<PKPaymentNetwork> *)bankCards {
    return [PKPaymentAuthorizationViewController canMakePaymentsUsingNetworks:bankCards];
}

+ (BOOL)setUpApplePayBankCard {
    if (@available(iOS 8.3, *)) {
        PKPassLibrary *library = [[PKPassLibrary alloc] init];
        [library openPaymentSetup];
        return YES;
    } else {
        return NO;
    }
}

- (void)payOrderInfo:(PayOrderInfo *)orderInfo result:(void (^)(BOOL, NSString *))result {
    _pay = orderInfo.pay;
    self.payResult = result;
    self.payState = @"start";
    self.viewController = orderInfo.viewController;
    if (_pay == PayAli) {
        [[AlipaySDK defaultService] payOrder:orderInfo.orderString fromScheme:orderInfo.scheme callback:nil];
    } else if (_pay == PayWX) {
        PayReq *payReq = [[PayReq alloc] init];
        payReq.openID = orderInfo.openID;
        payReq.partnerId = orderInfo.partnerId;
        payReq.prepayId = orderInfo.prepayId;
        payReq.nonceStr = orderInfo.nonceStr;
        payReq.timeStamp = orderInfo.timeStamp.unsignedIntValue;
        payReq.package = orderInfo.package;
        payReq.sign = orderInfo.sign;
        [WXApi sendReq:payReq];
    } else if (_pay == PayUnion) {
        [[UPPaymentControl defaultControl] startPay:orderInfo.orderString fromScheme:orderInfo.scheme mode:orderInfo.mode viewController:orderInfo.viewController];
    } else {
        PKPaymentRequest *request = [[PKPaymentRequest alloc] init];
        request.merchantIdentifier = orderInfo.merchantIdentifier;
        request.countryCode = @"CN";
        request.currencyCode = @"CNY";
        request.supportedNetworks = orderInfo.supportBankCards;
        request.merchantCapabilities = PKMerchantCapability3DS | PKMerchantCapabilityEMV;
        //账单地址,默认不显示
        if (@available(iOS 11.0, *)) {
            request.requiredBillingContactFields = [NSSet setWithArray:@[]];
        } else {
            request.requiredBillingAddressFields = PKAddressFieldNone;
        }
        //送货地址，默认是不显示，这个一般会在支付前进行选择
        if (@available(iOS 11.0, *)) {
            request.requiredShippingContactFields = [NSSet setWithArray:@[]];
        } else {
            request.requiredShippingAddressFields = PKAddressFieldNone;
        }
        //运输方式，快递
        if (orderInfo.shipMethods.count) {
            NSMutableArray *shipMethods = [NSMutableArray arrayWithCapacity:0];
            [orderInfo.shipMethods enumerateObjectsUsingBlock:^(PayShipMethod * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                NSDecimalNumber *price = [NSDecimalNumber decimalNumberWithString:obj.price];
                PKShippingMethod *method = [PKShippingMethod summaryItemWithLabel:obj.name amount:price];
                method.identifier = obj.identifier;
                method.detail = obj.detail;
                [shipMethods addObject:method];
                if (shipMethods.count == orderInfo.shipMethods.count) {
                    *stop = YES;
                }
            }];
            request.shippingMethods = shipMethods;
            //快递方式
            if (@available(iOS 8.3, *)) {
                request.shippingType = PKShippingTypeDelivery;
            } else {
                // Fallback on earlier versions
            }
        }
        //商品列表
        NSMutableArray *summaryItems = [NSMutableArray arrayWithCapacity:0];
        if (orderInfo.paySummaryItems.count) {
            [orderInfo.paySummaryItems enumerateObjectsUsingBlock:^(PaySummaryItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                NSDecimalNumber *price = [NSDecimalNumber decimalNumberWithString:obj.price];
                PKPaymentSummaryItem *item = [PKPaymentSummaryItem summaryItemWithLabel:obj.name amount:price];
                [summaryItems addObject:item];
                if (summaryItems.count == orderInfo.paySummaryItems.count) {
                    *stop = YES;
                }
            }];
        } else {
            NSAssert(orderInfo.paySummaryItems.count, @"商品信息必须传入");
        }
        request.paymentSummaryItems = summaryItems;
        //额外的信息
        if (orderInfo.applicationData) {
            request.applicationData = [orderInfo.applicationData dataUsingEncoding:NSUTF8StringEncoding];
        }
        //调用授权支付
        PKPaymentAuthorizationViewController *paymentVC = [[PKPaymentAuthorizationViewController alloc] initWithPaymentRequest:request];
        paymentVC.delegate = self;
        [orderInfo.viewController presentViewController:paymentVC animated:YES completion:nil];
    }
}

- (void)handleOpenURL:(NSURL *)url {
    self.payState = @"end";
    if (_pay == PayAli) {
        //跳转到支付宝APP支付的回传结果
        if ([url.host isEqualToString:@"safepay"]) {
            [[AlipaySDK defaultService] processOrderWithPaymentResult:url standbyCallback:^(NSDictionary *resultDic) {
                if ([resultDic[@"resultStatus"] integerValue] == 9000) {
                    self.payResult(YES, resultDic[@"result"]);
                } else {
                    self.payResult(NO, resultDic[@"result"]);
                }
            }];
        }
        //跳转到支付宝网页版支付的回传结果
        if ([url.host isEqualToString:@"platformapi"]) {
            [[AlipaySDK defaultService] processAuthResult:url standbyCallback:^(NSDictionary *resultDic) {
                if ([resultDic[@"resultStatus"] integerValue] == 9000) {
                    self.payResult(YES, resultDic[@"result"]);
                } else {
                    self.payResult(NO, resultDic[@"result"]);
                }
            }];
        }
    } else if (_pay == PayWX) {
        [WXApi handleOpenURL:url delegate:[PayService defaultService]];
    } else {
        [[UPPaymentControl defaultControl] handlePaymentResult:url completeBlock:^(NSString *code, NSDictionary *data) {
            if ([code isEqualToString:@"success"]) {
                NSData *signData = [NSJSONSerialization dataWithJSONObject:data options:0 error:nil];
                NSString *sign = [[NSString alloc] initWithData:signData encoding:NSUTF8StringEncoding];
                self.payResult(YES, sign);
            } else {
                self.payResult(NO, @"支付失败");
            }
        }];
    }
}

#pragma mark - WXApiDelegate 处理微信支付回调
- (void)onResp:(BaseResp *)resp {
    if ([resp isKindOfClass:[PayResp class]]) {
        if (resp.errCode == WXSuccess) {
            self.payResult(YES, @"支付成功");
        } else {
            self.payResult(NO, resp.errStr);
        }
    }
}

#pragma mark - PKPaymentAuthorizationViewControllerDelegate
//授权成功回调，在此方法里调用自己服务器验证是否支付成功，然后通过代理Block回传
- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didAuthorizePayment:(PKPayment *)payment completion:(void (^)(PKPaymentAuthorizationStatus))completion {
    if (self.handleApplePayAuthorizePayment) {
        BOOL auth = self.handleApplePayAuthorizePayment(payment);
        if (auth) {
            completion(PKPaymentAuthorizationStatusSuccess);
        } else {
            completion(PKPaymentAuthorizationStatusFailure);
        }
    }
}
//方法作用同上，iOS 11开始使用，代替上面的方法。
- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didAuthorizePayment:(PKPayment *)payment handler:(void (^)(PKPaymentAuthorizationResult *result))completion  API_AVAILABLE(ios(11.0)) {
    if (self.handleApplePayAuthorizePayment) {
        BOOL auth = self.handleApplePayAuthorizePayment(payment);
        PKPaymentAuthorizationResult *r = [[PKPaymentAuthorizationResult alloc] initWithStatus:PKPaymentAuthorizationStatusSuccess errors:nil];
        if (auth) {
            completion(r);
        } else {
            r.status = PKPaymentAuthorizationStatusFailure;
            completion(r);
        }
    }
}
//送货方式回调
//配送方式回调，如果需要根据不同的送货方式进行支付金额的调整，比如包邮和付费加速配送，可以实现该代理
- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didSelectShippingMethod:(PKShippingMethod *)shippingMethod completion:(void (^)(PKPaymentAuthorizationStatus, NSArray<PKPaymentSummaryItem *> * _Nonnull))completion {
    if (self.handleApplePayShippingMethod) {
        PaymentUpdate *update = self.handleApplePayShippingMethod(shippingMethod);
        completion(update.status, update.summaryItems);
    }
}
//送货方式回调 iOS 11开始使用
- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didSelectShippingMethod:(PKShippingMethod *)shippingMethod handler:(void (^)(PKPaymentRequestShippingMethodUpdate * _Nonnull))completion  API_AVAILABLE(ios(11.0)){
    if (self.handleApplePayShippingMethod) {
        PaymentUpdate *update = self.handleApplePayShippingMethod(shippingMethod);
        PKPaymentRequestShippingMethodUpdate *method = [[PKPaymentRequestShippingMethodUpdate alloc] initWithPaymentSummaryItems:update.summaryItems];
        method.status = update.status;
        completion(method);
    }
}


//送货地址回调
//如果需要根据送货地址调整送货方式，比如普通地区包邮+极速配送，偏远地区只有付费普通配送，进行支付金额重新计算，可以实现该代理，返回给系统
//shippingMethods配送方式，summaryItems账单列表
- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didSelectShippingContact:(PKContact *)contact completion:(void (^)(PKPaymentAuthorizationStatus, NSArray<PKShippingMethod *> *shippingMethods, NSArray<PKPaymentSummaryItem *> *summaryItems))completion {
    if (self.handleApplePayShippingAddress) {
        PaymentUpdate *update = self.handleApplePayShippingAddress(contact);
        completion(update.status, update.shippingMethods, update.summaryItems);
    }
}
//送货地址回调，iOS 11开始使用
- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didSelectShippingContact:(PKContact *)contact handler:(void (^)(PKPaymentRequestShippingContactUpdate * _Nonnull))completion  API_AVAILABLE(ios(11.0)) {
    if (self.handleApplePayShippingAddress) {
        PaymentUpdate *update = self.handleApplePayShippingAddress(contact);
        PKPaymentRequestShippingContactUpdate *contact = [[PKPaymentRequestShippingContactUpdate alloc] initWithErrors:nil paymentSummaryItems:update.summaryItems shippingMethods:update.shippingMethods];
        completion(contact);
    }
}

//支付完成或取消
- (void)paymentAuthorizationViewControllerDidFinish:(PKPaymentAuthorizationViewController *)controller {
    [self.viewController dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - 处理ios9.0后通过左上角返回或者其他非正常途径返回APP导致支付回调不成功的问题
- (void)enterForegroundNotification:(NSNotification *)notify {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.payState && [self.payState isEqualToString:@"start"]) {
            self.payState = @"end";
            if (self.handleBackToAppByUnusualWay) {
                self.handleBackToAppByUnusualWay();
            }
        }
    });
}

@end
