//
//  WorkoutDetails.swift
//  health
//
//  Created by Alexey on 26.05.2022.
//

import SwiftUI
import HealthKit
import CoreLocation

struct WorkoutDetails: View {
    let workout: HKWorkout
    
    @State private var locations: [CLLocation] = []
    @State private var steps: [Step] = []
    @State private var stepsCount: Double = 0
    @State private var heartRate: HeartRate?
    
    private var healthStore: HealthStore?
    
    @State private var durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
    
    init(workout: HKWorkout) {
        self.workout = workout
        healthStore = HealthStore()
    }
    
    func startDate(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy HH:mm:ss"
        return formatter.string(from: date)
    }
    
    func endDate(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func updateUIFromStatistics(_ statisticsCollection: HKStatisticsCollection) {
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let endDate = Date()
        statisticsCollection.enumerateStatistics(from: startDate, to: endDate) { (statistics, stop) in
            let count = statistics.sumQuantity()?.doubleValue(for: .count())
            let step = Step(count: Int(count ?? 0), date: statistics.startDate)
            if step.count > 0 {
                steps.append(step)
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                SummaryMetricView(
                    title: "Date",
                    value: "\(startDate(date: workout.startDate)) - \(endDate(date: workout.endDate))"
                )
                    .foregroundStyle(.black)
                SummaryMetricView(
                    title: "Total Time",
                  value: durationFormatter.string(from: workout.duration) ?? ""
                )
                    .foregroundStyle(.yellow)
                SummaryMetricView(
                    title: "Total Distance",
                    value: Measurement(value: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,  unit: UnitLength.meters)
                    .formatted(.measurement(width: .abbreviated, usage: .road, numberFormatStyle: .number.precision(.fractionLength(2))))
                )
                    .foregroundStyle(.green)
                SummaryMetricView(
                    title: "Count locations",
                    value: "\(locations.count)"
                )
                    .foregroundStyle(.black)
                SummaryMetricView(title: "Total Energy",
                      value: Measurement(value: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0,
                                         unit: UnitEnergy.kilocalories)
                        .formatted(.measurement(width: .abbreviated,
                                                usage: .workout,
                                                numberFormatStyle: .number.precision(.fractionLength(0)))))
                .foregroundStyle(.pink)
                SummaryMetricView(title: "Avg. Heart Rate", value: "\(heartRate?.avg ?? 0)")
                    .foregroundStyle(.orange)
                SummaryMetricView(title: "Heart Rate Range", value: "\(heartRate?.min ?? 0) - \(heartRate?.max ?? 0)")
                    .foregroundStyle(.orange)
                SummaryMetricView(
                    title: "Steps count:",
                    value: "\(stepsCount)"
                )
                .foregroundStyle(.black)
            }
            .padding()
        }
        .task {
            if let healthStore = healthStore {
                let workoutRoute = await healthStore.getWorkoutRoute(workout: workout)!
                
                if workoutRoute.count != 0 {
                    locations = await healthStore.getLocationDataForRoute(givenRoute: workoutRoute[0])
                }
                
                healthStore.countSteps(workout: workout, completion: { (count, error) in
                    stepsCount = count
                })
                
                healthStore.getHeartRate(workout: workout, completion: { (hr, error) in
                    heartRate = hr
                })
                
                
                
//                healthStore.calculateSteps(workout: workout, completion: { statisticsCollection in
//                    if let statisticsCollection = statisticsCollection {
//                        updateUIFromStatistics(statisticsCollection)
//                    }
//                })
            }
        }
    }
}

struct SummaryMetricView: View {
    var title: String
    var value: String

    var body: some View {
        Text(title)
            .foregroundStyle(.foreground)
        Text(value)
            .font(.system(.title2, design: .rounded).lowercaseSmallCaps())
        Divider()
    }
}

//struct WorkoutDetails_Previews: PreviewProvider {
//    static var previews: some View {
//        WorkoutDetails()
//    }
//}
