import SwiftState

typealias TomikStateMachine = StateMachine<TomikStateMachineStates, TomikStateMachineEvents>

enum TomikStateMachineEvents: EventType {
    case startStop, timerFired, skipRest
}

enum TomikStateMachineStates: StateType {
    case idle, work, rest
}
