import Foundation
import ObjectiveC

enum VideoRecorderReflectUtil {
    typealias VoidFunction = @convention(c) (AnyObject, Selector) -> Void

    typealias ObjectReturnFunction = @convention(c) (AnyObject, Selector) -> Unmanaged<AnyObject>?

    typealias IntReturnFunction = @convention(c) (AnyObject, Selector) -> Int32

    typealias ObjectArgumentFunction = @convention(c) (AnyObject, Selector, AnyObject?) -> Void

    typealias IntegerArgumentFunction = @convention(c) (AnyObject, Selector, Int) -> Void

    struct Invocation<Function> {
        let function: Function
        let target: AnyObject
        let selector: Selector
    }

    static func createClassInstance(_ className: String) -> NSObject? {
        guard let reflectClass = NSClassFromString(className) as? NSObject.Type else {
            print("Class \(className) not found")
            return nil
        }
        return reflectClass.init()
    }

    static func invocation<Function>(_ instance: AnyObject?, methodName: String, as type: Function.Type) -> Invocation<Function>? {
        print("invokeMethod methodName:\(methodName)")
        let selector = NSSelectorFromString(methodName)
        guard let instance = instance,
              let instanceClass = object_getClass(instance),
              class_respondsToSelector(instanceClass, selector),
              let implementation = class_getMethodImplementation(instanceClass, selector) else {
            print("instance is nil or Method:\(methodName) is not exist")
            return nil
        }
        return Invocation(function: unsafeBitCast(implementation, to: type), target: instance, selector: selector)
    }

    @discardableResult
    static func invokeObjectMethod(_ instance: AnyObject?, methodName: String) -> AnyObject? {
        guard let invocation = invocation(instance, methodName: methodName, as: ObjectReturnFunction.self) else {
            return nil
        }
        return invocation.function(invocation.target, invocation.selector)?.takeUnretainedValue()
    }

    static func invokeVoidMethod(_ instance: AnyObject?, methodName: String) {
        guard let invocation = invocation(instance, methodName: methodName, as: VoidFunction.self) else { return }
        invocation.function(invocation.target, invocation.selector)
    }

    static func invokeMethod(_ instance: AnyObject?, methodName: String, argument: AnyObject?) {
        guard let invocation = invocation(instance, methodName: methodName, as: ObjectArgumentFunction.self) else { return }
        invocation.function(invocation.target, invocation.selector, argument)
    }

    static func invokeMethod(_ instance: AnyObject?, methodName: String, integerArgument: Int) {
        guard let invocation = invocation(instance, methodName: methodName, as: IntegerArgumentFunction.self) else { return }
        invocation.function(invocation.target, invocation.selector, integerArgument)
    }

    static func safeValueForProperty(_ instance: AnyObject?, propertyName: String) -> AnyObject? {
        guard let instance = instance as? NSObject,
              instance.responds(to: NSSelectorFromString(propertyName)) else {
            return nil
        }
        return instance.value(forKey: propertyName) as AnyObject?
    }
}
