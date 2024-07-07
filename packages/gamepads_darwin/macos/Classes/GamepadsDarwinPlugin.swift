import Cocoa
import GameController
import FlutterMacOS

public class GamepadsDarwinPlugin: NSObject, FlutterPlugin {
    let channel: FlutterMethodChannel
    let gamepads = GamepadsListener()

    init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()

        self.gamepads.listener = onGamepadEvent
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "xyz.luan/gamepads", binaryMessenger: registrar.messenger)
        let instance = GamepadsDarwinPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "listGamepads":
            result(listGamepads())
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func onGamepadEvent(gamepadId: Int, gamepad: GCExtendedGamepad, element: GCControllerElement) {
        for (key, label, value) in getValues(element: element) {
            let arguments: [String: Any] = [
                "gamepadId": String(gamepadId),
                "gamepadName": gamepad.controller?.vendorName ?? "Unknown gamepad",
                "time": Int(getTimestamp(gamepad: gamepad)),
                "type": element.isAnalog ? "analog" : "button",
                "key": key,
                "value": value,
                "label": label ?? key,
            ]
            channel.invokeMethod("onGamepadEvent", arguments: arguments)
        }
    }

    private func getValues(element: GCControllerElement) -> [(String, String?, Float)] {
        if let element = element as? GCControllerButtonInput {
            var button: String = "Unknown button"
            if #available(macOS 11.0, *) {
                if (element.sfSymbolsName != nil) {
                    button = element.sfSymbolsName!
                }
            }
            
            return [(button,  getLabelForElement(element: element), element.value)]
        } else if let element = element as? GCControllerAxisInput {
            var axis: String = "Unknown axis"
            if #available(macOS 11.0, *) {
                if (element.sfSymbolsName != nil) {
                    axis = element.sfSymbolsName!
                }
            }
            return [(axis, getLabelForElement(element: element), element.value)]
        } else if let element = element as? GCControllerDirectionPad {
            return [
                (getNameForElement(element: element.up) ?? "Unknown direction pad", getLabelForElement(element: element.up), element.up.value),
                (getNameForElement(element: element.right) ?? "Unknown direction pad", getLabelForElement(element: element.right), element.right.value),
                (getNameForElement(element: element.down) ?? "Unknown direction pad", getLabelForElement(element: element.down), element.down.value),
                (getNameForElement(element: element.left) ?? "Unknown direction pad", getLabelForElement(element: element.left), element.left.value),
            ]
        } else {
            return []
        }
    }
    
    private func getNameForElement(element: GCControllerElement) -> String? {
        if #available(macOS 11.0, *) {
            return element.sfSymbolsName
        } else {
            return nil
        }
    }

    private func getLabelForElement(element: GCControllerElement) -> String? {
        if #available(macOS 11.0, *) {
            return element.localizedName
        } else {
            return nil
        }
    }

    private func getTimestamp(gamepad: GCExtendedGamepad) -> TimeInterval {
        if #available(macOS 11.0, *) {
            return gamepad.lastEventTimestamp
        } else {
            return Date().timeIntervalSince1970
        }
    }

    private func getName(gamepad: GCExtendedGamepad) -> String {
        if #available(macOS 11.0, *) {
            let device = gamepad.device
            return maybeConcat(device?.vendorName, device?.productCategory) ?? "Unknown device"
        } else {
            return "Unknown device"
        }
    }

    private func listGamepads() -> [[String: Any?]] {
        return gamepads.gamepads.enumerated().map { (index, gamepad) in
            [ "id": String(index), "name": getName(gamepad: gamepad) ]
        }
    }

    private func maybeConcat(_ string1: String?, _ string2: String) -> String {
        return maybeConcat(string1, string2)!
    }

    private func maybeConcat(_ strings: String?...) -> String? {
        let nonNull = strings.compactMap { $0 }
        if (nonNull.isEmpty) {
            return nil
        }
        return nonNull.joined(separator: "_")
    }
}

extension Optional {
    func map<T>(_ closure: (Wrapped) -> T) -> T? {
        if let value = self {
            return closure(value)
        } else {
            return nil
        }
    }
}
