//
//  ViewController.m
//  XLLLockTest
//
//  Created by 肖乐 on 2018/3/21.
//  Copyright © 2018年 IMMoveMobile. All rights reserved.
//

#import "ViewController.h"
#import <pthread.h>
#import <libkern/OSAtomic.h>

@interface ViewController ()
{
    NSLock *_lock;  //互斥锁
    dispatch_semaphore_t _semaphore;  //信号量
    pthread_mutex_t _pthread; //互斥锁
    // 加入就会有警告，被舍弃了
    __block OSSpinLock _spinLock;  //自旋锁
}

@property (nonatomic, assign) NSInteger tickets;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.tickets = 10;
    _lock = [[NSLock alloc] init];
    _semaphore = dispatch_semaphore_create(1);
    pthread_mutex_init(&_pthread, NULL);
    _spinLock = OS_SPINLOCK_INIT;
}

- (IBAction)clickAction:(id)sender {
    
    [self test2];
}

// 同步肯定会造成线程阻塞，所以对于卖票系统，我们肯定会使用异步。
// 异步派发+串行队列
- (void)test1
{
    // 创建串行队列
    dispatch_queue_t squeue = dispatch_queue_create("serial", DISPATCH_QUEUE_SERIAL);
    dispatch_async(squeue, ^{
        
        [self dealTask1];
    });
    dispatch_async(squeue, ^{
        
        [self dealTask1];
    });
    // 结论：现象是对的，且没有造成线程阻塞。但只在一个新线程上进行处理。效率很慢
}

// 异步派发+并行队列
- (void)test2
{
    // 创建并行队列
    dispatch_queue_t cqueue = dispatch_queue_create("concurrent", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(cqueue, ^{
        
        [self dealTask4];
    });
    dispatch_async(cqueue, ^{
        
        [self dealTask4];
    });
    // 结论，效率很快，开启了多个线程对外部线程数据self.sockets同时进行处理。造成了self.sockets出现问题。也就是线程安全问题
}


#pragma mark - 未加锁任务
- (void)dealTask1
{
    while (true) {
        [NSThread sleepForTimeInterval:0.5];
        if (self.tickets > 0)
        {
            self.tickets --;
            NSLog(@"剩余票数--%zd张--%@",self.tickets, [NSThread currentThread]);
        } else {
            NSLog(@"卖光了");
            // 逃离任务
            break;
        }
    }
}

#pragma mark - NSLock简单互斥锁
- (void)dealTask2
{
    [_lock lock];
    while (true) {
        [NSThread sleepForTimeInterval:0.5];
        if (self.tickets > 0)
        {
            self.tickets --;
            NSLog(@"剩余票数--%zd张--%@",self.tickets, [NSThread currentThread]);
        } else {
            NSLog(@"卖光了");
            // 逃离任务
            break;
        }
    }
    [_lock unlock];
    /**
     注意的是，不能多次调用lock，否则会造成死锁
     */
}

#pragma mark - @synchronized互互斥锁，性能很差
- (void)dealTask3
{
    @synchronized(self) {
        while (true) {
            [NSThread sleepForTimeInterval:0.5];
            if (self.tickets > 0)
            {
                self.tickets --;
                NSLog(@"剩余票数--%zd张--%@",self.tickets, [NSThread currentThread]);
            } else {
                NSLog(@"卖光了");
                // 逃离任务
                break;
            }
        }
    }
    /**
     不用显示的去创建锁对象，一般会使用self来加锁，注意这个对象必须是全局唯一的，必须保证多个线程同时访问的时候，@synchronize（OC对象）,必须保证这个对象是相同的。
     */
}

#pragma mark - dispatch_semaphore_t（信号量）
- (void)dealTask4
{
    // 每个队列任务执行前，需要等待前一个队列任务执行完成，这里是等待信号
    // 下个队列执行的时候，发现信号量为1，则-1执行任务，如果信号量为0，则等待
    // 信号量等待的time可以自定义，DISPATCH_TIME_FOREVER意为信号量不为1，永远不会往下执行。如果time设为3秒，则即使信号量不为1，3秒后也会执行改任务。
//    dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 10);
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    while (true) {
        [NSThread sleepForTimeInterval:0.5];
        if (self.tickets > 0)
        {
            self.tickets --;
            NSLog(@"剩余票数--%zd张--%@",self.tickets, [NSThread currentThread]);
        } else {
            NSLog(@"卖光了");
            // 逃离任务
            break;
        }
    }
    // 队列任务执行完成，信号量+1
    dispatch_semaphore_signal(_semaphore);
}

#pragma mark - pthread_mutex互斥锁
- (void)dealTask5
{
    pthread_mutex_lock(&_pthread);
    while (true) {
        [NSThread sleepForTimeInterval:0.5];
        if (self.tickets > 0)
        {
            self.tickets --;
            NSLog(@"剩余票数--%zd张--%@",self.tickets, [NSThread currentThread]);
        } else {
            NSLog(@"卖光了");
            // 逃离任务
            break;
        }
    }
    pthread_mutex_unlock(&_pthread);
}

// OSSpinLock 自旋锁 性能最好的锁，但是YY大神说已经不安全了
- (void)dealTask6
{
    OSSpinLockLock(&_spinLock);
    while (true) {
        [NSThread sleepForTimeInterval:0.5];
        if (self.tickets > 0)
        {
            self.tickets --;
            NSLog(@"剩余票数--%zd张--%@",self.tickets, [NSThread currentThread]);
        } else {
            NSLog(@"卖光了");
            // 逃离任务
            break;
        }
    }
    OSSpinLockUnlock(&_spinLock);
}


- (IBAction)testThread:(id)sender {
    
    NSLog(@"我没有被阻塞");
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
