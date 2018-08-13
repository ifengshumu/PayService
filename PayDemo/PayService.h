//
//  PayService.h
//  PayDemo
//
//  Created by 李志华 on 2018/8/9.
//  Copyright © 2018年 Chris Lee. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PassKit/PassKit.h>
#import "PayOrderInfo.h"


@interface PayService : NSObject
/**
 支付方式
 */
@property (nonatomic, assign, readonly) Pay pay;

/**
 处理ios9.0后通过左上角或者其他非正常途径返回APP导致支付回调不成功的问题
 @note 在支付页面进行调用处理
 @param handler 外部处理(调用自己服务验证支付是否成功)
 */
@property (nonatomic, copy) void(^handleBackToAppByUnusualWay)(void);

/**
 ApplePay授权成功后，根据PKPayment里的信息调用自己服务验证支付是否成功，成功返回YES，失败返回NO
 @note 在支付页面进行调用处理
 @param payment 订单信息(调用自己服务验证支付是否成功)
 */
@property (nonatomic, copy) BOOL(^handleApplePayAuthorizePayment)(PKPayment* payment);

/**
 ApplePay送货方式回调
 @return PKPaymentAuthorizationStatus,
 @return NSArray<PKPaymentSummaryItem *>
 */
@property (nonatomic, copy) PaymentUpdate*(^handleApplePayShippingMethod)(PKShippingMethod *shippingMethod);

/**
 ApplePay送货地址回调

 @return PKPaymentAuthorizationStatus,
 @return NSArray<PKShippingMethod *> *
 @return NSArray<PKPaymentSummaryItem *>
 */
@property (nonatomic, copy) PaymentUpdate*(^handleApplePayShippingAddress)(PKContact *address);

/**
 支付服务单利

 @return 单利
 */
+ (instancetype)defaultService;


/**
 是否支持微信支付
 */
+ (BOOL)isSupportWXPay;


/**
 注册微信
 */
+ (void)registerAppForWX:(NSString *)appID;

/**
 是否支持ApplePay
 */
+ (BOOL)isSupportApplePay;

/**
 ApplePay是否支持指定的银行卡
 
 @param bankCards 银行卡
 @return YES支持，NO不支持，调用setUpApplePayBankCard添加银行卡
 */
+ (BOOL)isApplePaySupportBankCards:(NSArray<PKPaymentNetwork> *)bankCards;

/**
 ApplePay添加银行卡
 */
+ (BOOL)setUpApplePayBankCard;

/**
 支付

 @param orderInfo 订单信息
 @param result 支付结果处理
 success:YES说明SDK回调支付成功，但最好是调用自己服务验证支付是否成功;
 data:支付宝返回的是json字符串结构的处理结果(https://docs.open.alipay.com/204/105301/)，微信是错误提示，银联是签名数据，去自己后台进行验签
 */
- (void)payOrderInfo:(PayOrderInfo *)orderInfo result:(void(^)(BOOL success, NSString *data))result;


/**
 在appDelegate.m里调用
 @method - (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(nullable NSString *)sourceApplication annotation:(id)annotation (9.0已废弃)
 @method - (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options

 @param url 回调url
 */
- (void)handleOpenURL:(NSURL *)url;


@end
