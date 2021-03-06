//
//  ReactionTypeGraph.swift
//  ReactionTypeGraph
//
//  Created by Евгений on 14.08.2021.
//

import SwiftUI

let secondaryColor = Color(white: 0.65)

struct GraphPoint: View {
    var color: Color
    
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            
            Circle()
                .fill(color)
                .overlay(
                    Circle()
                        .fill(Color("Background"))
                        .frame(width: size.width / 2, height: size.width / 2)
                )
        }
    }
}

struct StatReactionType {
    var values: [Int] = []
    var dataPoints: [CGPoint] = []
    
    let maxDegree: Int
    let minDegree: Int
    
    var firstControlPoints: [CGPoint?] = []
    var secondControlPoints: [CGPoint?] = []
    
    var rhsArray = [CGPoint]()
    var a = [CGFloat]()
    var b = [CGFloat]()
    var c = [CGFloat]()
    
    func getPercentage(idx: Int) -> CGFloat {
        if maxDegree == minDegree {
            return 0
        }
        return CGFloat(values[idx] - minDegree) / CGFloat(maxDegree - minDegree)
    }
    
    mutating func calculatePoints() {
        dataPoints = []
        
        if values.count == 0 {
            return
        }
        
        for i in 0..<values.count {
            dataPoints.append(.init(x: CGFloat(i) / CGFloat(values.count - 1), y: 1 - getPercentage(idx: i)))
        }
    }
    
    mutating func calculateRHS() {
        let count = dataPoints.count - 1
        
        if count <= 0 {
            return
        }
        
        for i in 0..<count {
            var rhsValueX: CGFloat = 0
            var rhsValueY: CGFloat = 0

            let P0 = dataPoints[i]
            let P3 = dataPoints[i+1]

            if i == 0 {
                a.append(0)
                b.append(2)
                c.append(1)

                rhsValueX = P0.x + 2*P3.x
                rhsValueY = P0.y + 2*P3.y
            } else if i == count-1 {
                a.append(2)
                b.append(7)
                c.append(0)

                rhsValueX = 8*P0.x + P3.x
                rhsValueY = 8*P0.y + P3.y
            } else {
                a.append(1)
                b.append(4)
                c.append(1)

                rhsValueX = 4*P0.x + 2*P3.x
                rhsValueY = 4*P0.y + 2*P3.y
            }

            rhsArray.append(CGPoint(x: rhsValueX, y: rhsValueY))
        }
        
        for i in 1..<count {
            let rhsValueX = rhsArray[i].x
            let rhsValueY = rhsArray[i].y

            let prevRhsValueX = rhsArray[i-1].x
            let prevRhsValueY = rhsArray[i-1].y

            let m = a[i]/b[i-1]
            b[i] -= m * c[i-1]

            let r2x = rhsValueX - m * prevRhsValueX
            let r2y = rhsValueY - m * prevRhsValueY

            rhsArray[i] = CGPoint(x: r2x, y: r2y)
        }
    }
    
    mutating func calculateControls() {
        let count = dataPoints.count - 1
        
        if count <= 0 {
            return
        }
        
        firstControlPoints = Array(repeating: .zero, count: count)
        
        let lastControlPointX = rhsArray[count-1].x/b[count-1]
        let lastControlPointY = rhsArray[count-1].y/b[count-1]

        firstControlPoints[count-1] = CGPoint(x: lastControlPointX, y: lastControlPointY)

        for i in (0...count-2).reversed() {
            if let nextControlPoint = firstControlPoints[i+1] {
                let controlPointX = (rhsArray[i].x - c[i] * nextControlPoint.x) / b[i]
                let controlPointY = (rhsArray[i].y - c[i] * nextControlPoint.y)/b[i]

                firstControlPoints[i] = CGPoint(x: controlPointX, y: controlPointY)
            }
        }
        
        for i in 0..<count {
            if i == count-1 {
                let P3 = dataPoints[i+1]
                guard let P1 = firstControlPoints[i] else{
                    continue
                }
                let controlPointX = (P3.x + P1.x)/2
                let controlPointY = (P3.y + P1.y)/2

                secondControlPoints.append(CGPoint(x: controlPointX, y: controlPointY))
            } else {
                let P3 = dataPoints[i+1]
                guard let nextP1 = firstControlPoints[i+1] else { continue }

                let controlPointX = 2*P3.x - nextP1.x
                let controlPointY = 2*P3.y - nextP1.y
                secondControlPoints.append(CGPoint(x: controlPointX, y: controlPointY))
            }
        }
    }
    
    mutating func calculate() {
        calculatePoints()
        calculateRHS()
        calculateControls()
    }
}

func maxDegree(maximumValue: Int) -> Int {
    let scale = scale(maximumValue: maximumValue)
    return (maximumValue + scale) / scale * scale
}

func minDegree(minimumValue: Int, maximumValue: Int) -> Int {
    let scale = scale(maximumValue: maximumValue)
    return max(0,(minimumValue - scale) / scale * scale)
}

struct Degree: Identifiable {
    var id: Int
    var description: String
}

func degreeDescriptions(minimumValue: Int, maximumValue: Int) -> [Degree] {
    let maxDegree = maxDegree(maximumValue: maximumValue)
    let minDegree = minDegree(minimumValue: minimumValue, maximumValue: maximumValue)
    let scale = scale(maximumValue: maximumValue)
    var currentDegree = minDegree
    var result = [Degree]()
    let count = (maxDegree - minDegree) / scale + 1
    while currentDegree <= maxDegree {
        if currentDegree >= 0 {
            result.append(.init(id: count - 1 - result.count, description: shortNumber(currentDegree)))
        }
        currentDegree += scale
    }
    return result
}

var typeGraphIntervals: [Range<Int>] = [
    21..<27,
     3..<9,
     9..<15,
    15..<21
]

func typeGraphIdx(time: Int) -> Int {
    for intervalIdx in 0..<typeGraphIntervals.count {
        let interval = typeGraphIntervals[intervalIdx]
        if interval.contains(time) || interval.contains(time + 24) {
            return intervalIdx
        }
    }
    return 0
}

struct ReactionTypeGraph: View {
    var types: [StatReactionType]
    var reactions: [Reaction]
    
    var minValue: Int
    var maxValue: Int
    
    let minDegree: Int
    let maxDegree: Int
    
    let bottomDegrees: [String]
    
    func adapt(point: CGPoint, size: CGSize) -> CGPoint {
        return CGPoint(x: point.x * size.width, y: point.y * size.height)
    }
    
    func circleRect(center: CGPoint, radius: CGFloat) -> CGRect {
        return CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius)
    }
    
    func getPath(size: CGSize, reactionIdx: Int) -> Path {
        var path = Path()
        for i in 0..<4 {
            var point1 = types[reactionIdx].dataPoints[i]
            var point2 = types[reactionIdx].dataPoints[i+1]
            if var control1 = types[reactionIdx].firstControlPoints[i],
               var control2 = types[reactionIdx].secondControlPoints[i] {
                point1 = adapt(point: point1, size: size)
                point2 = adapt(point: point2, size: size)
                control1 = adapt(point: control1, size: size)
                control2 = adapt(point: control2, size: size)
                
                path.move(to: point1)
                path.addCurve(to: point2, control1: control1, control2: control2)
                path.addEllipse(in: circleRect(center: point1, radius: 6))
            }
        }
        var lastPoint = types[reactionIdx].dataPoints[4]
        lastPoint = adapt(point: lastPoint, size: size)
        path.addEllipse(in: circleRect(center: lastPoint, radius: 6))
        return path
    }
    
    func getMaskPath(size: CGSize, reactionIdx: Int) -> Path {
        var path = Path()
        for i in 0..<5 {
            var point = types[reactionIdx].dataPoints[i]
            point = adapt(point: point, size: size)
            path.addEllipse(in: circleRect(center: point, radius: 5))
        }
        return path
    }
    
    var body: some View {
        HStack(spacing: 0) {
            HStack {
                VStack {
                    ForEach(degreeDescriptions(minimumValue: minValue, maximumValue: maxValue).reversed()) { degree in
                        if degree.id != 0 {
                            Spacer()
                        }
                        Text(degree.description)
                    }
                }
                Rectangle()
                    .fill(Color(white: 0.3))
                    .frame(width: 1)
            }
                .padding(.bottom, 25)
            VStack(spacing: 0) {
                Spacer()
                GeometryReader { proxy in
                    let size = proxy.size
                    
                    ZStack {
                        ForEach(0..<reactions.count) { reactionIdx in
                            if let selectionIdx = reactions[reactionIdx].statSelectionIdx {
                                getPath(size: size, reactionIdx: reactionIdx)
                                    .stroke(reactionColors[selectionIdx], lineWidth: 3)
                                getMaskPath(size: size, reactionIdx: reactionIdx)
                                    .fill(Color("Background"))
                            }
                        }
                    }
                }
                Rectangle()
                    .fill(Color(white: 0.3))
                    .frame(height: 1)
                    .padding(.bottom, 5)
                    .zIndex(-1)
                HStack {
                    ForEach(bottomDegrees.indices) { i in
                        if i != 0 {
                            Spacer()
                        }
                        Text("\(bottomDegrees[i])")
                    }
                }
                .frame(height: 20)
            }
        }
        .font(.footnote)
        .foregroundColor(secondaryColor)
    }
    
    init(values: [[Int]], reactions: [Reaction], duration: Double) {
        self.reactions = reactions
        self.bottomDegrees = getBottomDegrees(maxValue: (duration + 30) / 60, count: 5, leadingZero: false)
        
        var minValueU, maxValueU: Int?
        for i in 0..<values.count {
            if reactions[i].statSelectionIdx != nil {
                let value = values[i]
                for val in value {
                    if let minValue = minValueU {
                        if minValue > val {
                            minValueU = val
                        }
                    } else {
                        minValueU = val
                    }
                    if let maxValue = maxValueU {
                        if maxValue < val {
                            maxValueU = val
                        }
                    } else {
                        maxValueU = val
                    }
                }
            }
        }
        self.maxValue = maxValueU ?? 0
        self.minValue = minValueU ?? 0
        self.types = []
        self.minDegree = VKPodcasts.minDegree(minimumValue: minValue, maximumValue: maxValue)
        self.maxDegree = VKPodcasts.maxDegree(maximumValue: maxValue)
        for value in values {
            var type = StatReactionType(values: value, maxDegree: maxDegree, minDegree: minDegree)
            type.calculate()
            types.append(type)
        }
    }
}

struct ReactionTypeGraph_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color("Background")
                .edgesIgnoringSafeArea(.all)
            ReactionTypeGraph(values: [
                
            ], reactions: [
            
            ], duration: 0)
                .frame(width: 320, height: 165)
        }
    }
}
