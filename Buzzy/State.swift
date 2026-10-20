import SwiftState

typealias BuzzyStateMachine = StateMachine<BuzzyStateMachineStates, BuzzyStateMachineEvents>

enum BuzzyStateMachineEvents: EventType {
    case startStop, timerFired, skipRest
}

enum BuzzyStateMachineStates: StateType {
    case idle, work, rest
}
