//
//  ContentView.swift
//  health
//
//  Created by Alexey on 26.05.2022.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    @State private var workouts: [HKWorkout] = []
    
    @State private var durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
    
    static let startStackDateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy HH:mm:ss"
        return formatter
    }()
    
    static let endStackDateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    
    private var healthStore: HealthStore?

    
    init() {
        healthStore = HealthStore()
    }
    
    var body: some View {
        NavigationView {
            List(workouts, id: \.self) { workout in
                NavigationLink(destination: WorkoutDetails(workout: workout)) {
                    HStack {
                        Capsule()
                                .frame(width: 4)
                                .foregroundColor(.accentColor)
                        VStack(alignment: .leading) {
                            Text("\(workout.startDate, formatter: Self.startStackDateFormat) - \(workout.endDate, formatter: Self.endStackDateFormat)")
                            Text("\(Measurement(value: workout.totalDistance?.doubleValue(for: .meter()) ?? 0, unit: UnitLength.meters).formatted(.measurement(width: .abbreviated, usage: .road, numberFormatStyle: .number.precision(.fractionLength(2))))) - \(durationFormatter.string(from: workout.duration) ?? "")")
                        }
                    }
                }
            }
                .onAppear {
                    if let healthStore = healthStore {
                        healthStore.requestAuthorization { success in
                            if success {
                                Task {
                                    workouts = await healthStore.readWorkouts()!
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Running workouts")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
