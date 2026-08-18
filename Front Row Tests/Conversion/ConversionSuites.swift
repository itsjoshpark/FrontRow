//
//  ConversionSuites.swift
//  Front Row Tests
//

import Testing

/// The suites that launch child processes, held apart from one another and run one test at a time.
///
/// `ConversionResourceTests` counts the descriptors the whole test host has open, and every child
/// anywhere in the bundle holds four of its own for as long as it runs - neighbouring pipes land
/// in the count and read as a leak. Within a suite the tests block on their children and contend
/// for the queues serving those pipes.
@Suite(.serialized)
struct ConversionSuites {}
