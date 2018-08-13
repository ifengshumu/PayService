//
//  PayOrderInfo.h
//  PayDemo
//
//  Created by 李志华 on 2018/8/10.
//  Copyright © 2018年 Chris Lee. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PassKit/PKConstants.h>

@class PKShippingMethod;
@class PKPaymentSummaryItem;

@interface PayShipMethod : NSObject
@property (nonatomic, copy) NSString *name;//快递名称
@property (nonatomic, copy) NSString *price;
@property (nonatomic, copy) NSString *identifier;//标识，唯一
@property (nonatomic, copy) NSString *detail;//具体描述
@end

@interface PaySummaryItem : NSObject
@property (nonatomic, copy) NSString *name;//商品名称
@property (nonatomic, copy) NSString *price;
@end

@interface PaymentUpdate : NSObject
@property (nonatomic, assign) PKPaymentAuthorizationStatus status;
@property (nonatomic, copy) NSArray<PKPaymentSummaryItem *> *summaryItems;
@property (nonatomic, copy) NSArray<PKShippingMethod *> *shippingMethods;
@end



typedef NS_ENUM(NSUInteger, Pay) {
    PayAli,
    PayWX,
    PayUnion,
    PayApple
};

@interface PayOrderInfo : NSObject
/** 支付类型 */
@property (nonatomic, assign) Pay pay;


/*支付宝支付*/
/** 在info.plist的URL Types里定义，用于支付结果回调 */
@property (nonatomic, copy) NSString *scheme;
/** 向服务获取的经过签名加密的订单字符串 */
@property (nonatomic, copy) NSString *orderString;


/*微信支付*/
/** 由用户微信号和AppID组成的唯一标识，发送请求时第三方程序必须填写，用于校验微信用户是否换号登录*/
@property (nonatomic, retain) NSString* openID;
/** 商家向财付通申请的商家id */
@property (nonatomic, retain) NSString *partnerId;
/** 预支付订单 */
@property (nonatomic, retain) NSString *prepayId;
/** 随机串，防重发 */
@property (nonatomic, retain) NSString *nonceStr;
/** 时间戳，防重发 */
@property (nonatomic, assign) NSNumber *timeStamp;
/** 商家根据财付通文档填写的数据和签名 */
@property (nonatomic, retain) NSString *package;
/** 商家根据微信开放平台文档对数据做的签名 */
@property (nonatomic, retain) NSString *sign;

/*银联支付(需要上面的scheme和orderString)*/
/** 支付环境 01:测试环境 00:生产环境*/
@property (nonatomic, copy) NSString *mode;
/** 启动支付控件的viewController*/
@property (nonatomic, strong) UIViewController *viewController;


/*ApplePay(需要上面的viewController)*/
/** 在苹果开发者中心申请的商户ID*/
@property (nonatomic, copy) NSString *merchantIdentifier;
/** 支持的银行卡*/
@property (nonatomic, copy) NSArray<PKPaymentNetwork> *supportBankCards;
/** 快递信息,不传不显示*/
@property (nonatomic, copy) NSArray<PayShipMethod *> *shipMethods;
/** 商品信息,最后一个是总价,必须传入*/
@property (nonatomic, copy) NSArray<PaySummaryItem *> *paySummaryItems;
/** 额外信息,用以标识此次支付,eg:@"goodsID=Alex",会在授权成功后包含在PKPaymentToken里*/
@property (nonatomic, copy) NSString *applicationData;

@end
