# Rookie and Experience Badges

## Feature Overview
Players now display compact visual badges indicating their NFL experience level:
- **Rookie Star Badge ⭐**: Gold circular badge with white star icon for rookies
- **Experience Badge (1-15+)**: Dark circular badge with year number for veterans

## Visual Design

### Rookie Star Badge (yearsExp = 0)
```
   ⭐
  ╱ ╲   ← Gold circular background (amber.shade400)
 │ ★ │    White star icon (14px)
  ╲ ╱     Subtle shadow for depth
   ─      28px diameter circle
```

### Experience Badge (yearsExp > 0)
```
  ┌───┐
  │ 8 │  ← Dark gray circle (grey.shade800)
  └───┘    Grey border (grey.shade600)
           White text (11px, bold)
           28x28 circle
           Examples: "1", "2", "8", "12"
```

## Implementation

### Location
Badges appear in the top-right corner of each player card, above the age indicator.

### Code Structure
```dart
if (player.yearsExp != null) ...[
  if (player.yearsExp == 0)
    // Rookie star badge - circular gold with white star
    Container(
      padding: EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.amber.shade400,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(...)],  // Subtle glow
      ),
      child: Icon(Icons.star, size: 14, color: Colors.white),
    )
  else
    // Experience badge - circular with year number
    Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade600),
      ),
      child: Text('${player.yearsExp}'),  // Just the number
    ),
]
```

## Data Source
- Field: `years_exp` from `players_raw` table
- Source: Sleeper API provides NFL experience for all players
- Rookies: `years_exp = 0`
- Veterans: `years_exp = 1, 2, 3, ...`

## Examples

### Example Players on th0rjc's Roster:
| Player | Position | Years Exp | Badge Display |
|--------|----------|-----------|---------------|
| Caleb Williams | QB | 1 | `(1)` dark circle |
| Rashee Rice | WR | 2 | `(2)` dark circle |
| Kyle Pitts | TE | 4 | `(4)` dark circle |
| Evan Engram | TE | 8 | `(8)` dark circle |

### Rookies in League:
| Player | Position | Years Exp | Badge Display |
|--------|----------|-----------|---------------|
| Woody Marks | RB | 0 | `⭐` gold star |
| Cam Skattebo | RB | 0 | `⭐` gold star |
| Mason Taylor | TE | 0 | `⭐` gold star |

## Visual Hierarchy

Player card layout (right side):
```
┌────────────────────────────┐
│ Name                   ⭐  │ ← Rookie star (gold circle)
│ POS, TEAM • #00    age 22  │ ← Smaller age text
└────────────────────────────┘
```

Or for veterans:
```
┌────────────────────────────┐
│ Name                  (8)  │ ← Experience circle (dark)
│ POS, TEAM • #00    age 30  │ ← Smaller age text
└────────────────────────────┘
```

## Color Scheme

### Rookie Star Badge
- Background: `Colors.amber.shade400` (#FFA726) - Gold/amber
- Icon: White star (`Icons.star`, 14px)
- Shape: Perfect circle (28x28)
- Shadow: Amber glow for emphasis
- Purpose: Eye-catching indicator of rookie status

### Experience Badge
- Background: `Colors.grey.shade800` (#424242) - Dark gray
- Border: `Colors.grey.shade600` (#757575) - Medium gray border
- Text: White with 70% opacity, 11px bold
- Shape: Perfect circle (28x28)
- Purpose: Compact year indicator that works well on dark backgrounds

## User Value
- **Quick Identification**: Spot rookies at a glance (green = new talent)
- **Experience Context**: Understand player tenure (1yr vs 8yr veteran)
- **Draft Strategy**: Helps with dynasty/keeper league decisions
- **Player Development**: Track player progression over time

## Future Enhancements
- [ ] Multi-year rookie badge (show draft year: "R '24")
- [ ] Veteran icon for 10+ year players
- [ ] Color-code experience ranges (0-2yr, 3-5yr, 6-9yr, 10+yr)
- [ ] Show draft round/pick for rookies
- [ ] Experience trend indicators (breakout candidates)
