import UIKit

class EnlargedHitAreaButton: UIButton {
    
    /// Default hit test expansion is 20pt on all sides.
    /// Modify this property to change the hit area expansion.
    var hitTestEdgeInsets: UIEdgeInsets = UIEdgeInsets(top: -20, left: -20, bottom: -20, right: -20)
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // If the button is hidden or user interaction is disabled, strictly delegate to super or return false
        guard !isHidden, isUserInteractionEnabled, alpha > 0.01 else {
            return false
        }
        
        let relativeFrame = self.bounds
        // A negative inset expands the rectangle
        let hitFrame = relativeFrame.inset(by: hitTestEdgeInsets)
        return hitFrame.contains(point)
    }
}
