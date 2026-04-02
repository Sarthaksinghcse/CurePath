**CurePath** is a comprehensive and intelligent iOS application designed to act as a personal first-aid and wound management assistant. It helps users identify acute medical injuries, provides immediate situational guidance, and tracks the healing progression over time.

Based on the project structure and its models, here are its primary features and capabilities:

### 1. AI-Powered Injury Scanning
The app utilizes an on-device Machine Learning model (`WoundClassifier.mlmodel`) to analyze camera input and classify different types of injuries. It can detect a variety of conditions, including cuts, burns, abrasions, lacerations, sprains, nosebleeds, and venomous bites. 

### 2. Interactive First-Aid Guidance
Once an injury is classified, CurePath provides immediate, step-by-step first-aid protocols tailored to that specific injury. 
- The guides include rich instructions with timers (e.g., "apply pressure for 5 minutes").
- Built-in animations (`FirstAidAnimationStep`) provide visual demonstrations (like the RICE method for a sprain or cooling techniques for a burn).
- Audio voice assistance helps guide users hands-free during emergency moments.

### 3. Recovery Tracking & Daily Check-ins
For wounds that take time to heal, the app offers a **Daily Check-In** feature. Users can log daily photos of the injury, and the app calculates specific metrics such as the wound's bounding box area, pixel density, and a computed "wound score." Based on these data points, it predicts the recovery trend—whether the injury is *Healing*, *Stable*, or *Worsening*.

### 4. Safety Warnings & Medical Escalation 
The app doesn't act as a replacement for emergency services; instead, it incorporates critical rules for when a user should seek professional help. It tracks metrics that might suggest an infection or stagnation in healing and provides clear warnings (e.g., "See a doctor if the cut is deep or jagged").

In summary, CurePath bridges the gap between the initial occurrence of an injury and complete recovery by combining immediate, actionable first aid with long-term, AI-assisted health monitoring.
