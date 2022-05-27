//
//  HealthStore.swift
//  health
//
//  Created by Alexey on 26.05.2022.
//

import Foundation
import HealthKit
import CoreLocation

extension Date {
    static func mondayAt12AM() -> Date {
        return Calendar(identifier: .iso8601).date(from: Calendar(identifier: .iso8601).dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
    }
}

class HealthStore {
    var healthStore: HKHealthStore?
    var query: HKStatisticsCollectionQuery?
    
    init() {
        if HKHealthStore.isHealthDataAvailable() && healthStore == nil {
            healthStore = HKHealthStore()
        }
    }
    
    func calculateSteps(workout: HKWorkout, completion: @escaping (HKStatisticsCollection?) -> Void) {
        let stepType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!
        let anchorDate = Calendar(identifier: .iso8601).date(from: Calendar(identifier: .iso8601).dateComponents([.yearForWeekOfYear, .weekOfYear], from: workout.endDate))!
        let intervalComponents = DateComponents(second: 5)
        
        
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)
        query  = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: anchorDate,
            intervalComponents: intervalComponents
        )
        
        query!.initialResultsHandler = { query, statisticsCollection, error in
           completion(statisticsCollection)
        }
        
        if let healthStore = healthStore, let query = self.query {
            healthStore.execute(query)
        }
    }
    
    func countSteps(workout: HKWorkout, completion: @escaping (Double, NSError?) -> Void) {
        let stepType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!
//        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: [])
        
        let workoutPredicate = HKQuery.predicateForObjects(from: workout)
        let startDateSort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let q = HKSampleQuery(
            sampleType: stepType,
            predicate: workoutPredicate,
            limit: 0,
            sortDescriptors: [startDateSort],
            resultsHandler: { _, results, error in
                var steps: Double = 0
                
                if results!.count > 0 {
                    for result in results as! [HKQuantitySample] {
                        steps += result.quantity.doubleValue(for: HKUnit.count())
                    }
                }
                
                completion(steps, error as NSError?)
            }
        )
        
        if let healthStore = healthStore {
            healthStore.execute(q)
        }
    }
    
    func getSteps(workout: HKWorkout, completion: @escaping (Double, NSError?) -> Void) {
        let type = HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount) // The type of data we are requesting
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: []) // Our search predicate which will fetch all steps taken today

        if let healthStore = healthStore, let _ = self.query {
            // The actual HealthKit Query which will fetch all of the steps and add them up for us.
            let query = HKSampleQuery(sampleType: type!, predicate: predicate, limit: 0, sortDescriptors: nil) { _, results, error in
                var steps: Double = 0

                if results!.count > 0
                {
                    for result in results as! [HKQuantitySample]
                    {
                        // checking and adding manually added steps
                        if result.sourceRevision.source.name == "Health" {
                            // these are manually added steps
                            steps += result.quantity.doubleValue(for: HKUnit.count())
                        }
                        else{
                            // these are auto detected steps which we do not want from using HKSampleQuery
                        }
                    }
                }
                completion(steps, error as NSError?)
            }
            
            healthStore.execute(query)
        }
    }
    
    
    func readWorkouts() async -> [HKWorkout]? {
        let running = HKQuery.predicateForWorkouts(with: .running)

        let samples = try! await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
            if let healthStore = healthStore {
                healthStore.execute(
                    HKSampleQuery(
                        sampleType: .workoutType(),
                        predicate: running,
                        limit: HKObjectQueryNoLimit,
                        sortDescriptors: [.init(keyPath: \HKSample.startDate, ascending: false)],
                        resultsHandler: { query, samples, error in
                            if let hasError = error {
                                continuation.resume(throwing: hasError)
                                return
                            }

                            guard let samples = samples else {
                                fatalError("*** Invalid State: This can only fail if there was an error. ***")
                            }

                            continuation.resume(returning: samples)
                        }))
            }
        }

        guard let workouts = samples as? [HKWorkout] else {
            return nil
        }

        return workouts
    }
    
    func getWorkoutRoute(workout: HKWorkout) async -> [HKWorkoutRoute]? {
        let byWorkout = HKQuery.predicateForObjects(from: workout)

        let samples = try! await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
            if let healthStore = healthStore {
                healthStore.execute(HKAnchoredObjectQuery(type: HKSeriesType.workoutRoute(), predicate: byWorkout, anchor: nil, limit: HKObjectQueryNoLimit, resultsHandler: { (query, samples, deletedObjects, anchor, error) in
                    if let hasError = error {
                        continuation.resume(throwing: hasError)
                        return
                    }

                    guard let samples = samples else {
                        return
                    }

                    continuation.resume(returning: samples)
                }))
            }
        }

        guard let workouts = samples as? [HKWorkoutRoute] else {
            return nil
        }

        return workouts
    }

    func getLocationDataForRoute(givenRoute: HKWorkoutRoute) async -> [CLLocation] {
        let locations = try! await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CLLocation], Error>) in
            var allLocations: [CLLocation] = []

            // Create the route query.
            let query = HKWorkoutRouteQuery(route: givenRoute) { (query, locationsOrNil, done, errorOrNil) in

                if let error = errorOrNil {
                    continuation.resume(throwing: error)
                    return
                }

                guard let currentLocationBatch = locationsOrNil else {
                    fatalError("*** Invalid State: This can only fail if there was an error. ***")
                }

                allLocations.append(contentsOf: currentLocationBatch)

                if done {
                    continuation.resume(returning: allLocations)
                }
            }

            if let healthStore = healthStore {
                healthStore.execute(query)
            }
        }

        return locations
    }
    
    func getHeartRate(workout: HKWorkout, completion: @escaping (HeartRate, NSError?) -> Void) {
//        guard let sampleType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
//            return
//        }
        
        let typeHeart = HKQuantityType.quantityType(forIdentifier: .heartRate)
        
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictEndDate)
//        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
//        let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: Int(HKObjectQueryNoLimit), sortDescriptors: [sortDescriptor]) { (sample, results, error) in
        let query = HKStatisticsQuery(quantityType: typeHeart!, quantitySamplePredicate: predicate, options: [.discreteAverage, .discreteMin, .discreteMax], completionHandler: {(_: HKStatisticsQuery, result: HKStatistics?, error: Error?) -> Void in
            guard error == nil else {
                return
            }
            
            DispatchQueue.main.async(execute: {() -> Void in
                let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                let minHeartRate = result?.minimumQuantity()?.doubleValue(for: heartRateUnit) ?? 0
                let maxHeartRate = result?.maximumQuantity()?.doubleValue(for: heartRateUnit) ?? 0
                let averageHeartRate = result?.averageQuantity()?.doubleValue(for: heartRateUnit) ?? 0
                let heartRate = HeartRate(min: Int(minHeartRate), max: Int(maxHeartRate), avg: Int(averageHeartRate))
                completion(heartRate, error as NSError?)
            })
            
            
//            let data = results![0] as! HKQuantitySample
//            let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
//            let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
//            let mostRecentQuantity = results.mostRecentQuantity()?.doubleValue(for: heartRateUnit) ?? 0
//            let averageQuantity = results.averageQuantity()?.doubleValue(for: heartRateUnit) ?? 0
        })
        
        healthStore?.execute(query)
    }
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        let read: Set = [
            HKQuantityType.quantityType(forIdentifier: .vo2Max)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!,
            .workoutType(),
            HKSeriesType.activitySummaryType(),
            HKSeriesType.workoutRoute(),
            HKSeriesType.workoutType(),
        ]
        
        guard let healthStore = self.healthStore else { return completion(false) }
        
        healthStore.requestAuthorization(toShare: [], read: read) { (success, error) in
            completion(success)
        }
    }
}
