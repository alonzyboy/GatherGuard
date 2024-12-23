# GatherGuard

A decentralized Proof of Attendance Protocol (POAP) smart contract system with cross-network reward multipliers, built on Clarity.

## Overview

GatherGuard is a sophisticated smart contract system that enables event organizers to create verifiable proof of attendance tokens (POAPs) with an innovative cross-network rewards mechanism. The system allows attendees to earn and accumulate merit points across different network partnerships, with multipliers increasing their rewards based on participation across multiple platforms.

## Features

- **Proof of Attendance NFTs**: Mint unique NFTs as proof of attendance for gatherings
- **Merit Points System**: Earn and redeem merit points for participation
- **Cross-Network Rewards**: Benefit from multipliers when participating across partner networks
- **Scalable Architecture**: Support for up to 1,000 attendees per gathering
- **Flexible Network Partnerships**: Create and manage partnerships with different platforms
- **Comprehensive Validation**: Built-in safeguards for all parameters and operations

## Smart Contract Structure

### Core Components

1. **Non-Fungible Tokens**
   - `attendance-proof`: Represents attendance at gatherings
   - `merit-token`: Represents redeemable rewards

2. **Data Maps**
   - `gatherings`: Stores gathering details and configurations
   - `attendee-proofs`: Tracks NFTs owned by attendees
   - `attendee-merits`: Manages merit points and multipliers
   - `gathering-attendees`: Lists participants for each gathering
   - `network-partnerships`: Defines partnership multipliers

### Key Functions

#### Administrative Functions

```clarity
(create-network-partnership (network-tag (string-ascii 20)) (multiplier uint))
(create-gathering (title (string-ascii 50)) (timestamp uint) (capacity uint) (merit-points uint) (network-tags (list 10 (string-ascii 20))))
```

#### Attendee Functions

```clarity
(join-gathering (gathering-id uint))
(claim-merits (points uint))
```

#### Read-Only Functions

```clarity
(get-attendee-proofs (attendee principal))
(get-attendee-merits (attendee principal))
(get-gathering-details (gathering-id uint))
(get-network-partnership (network-tag (string-ascii 20)))
```

## System Constraints

### Gathering Constraints
- Maximum title length: 50 characters
- Maximum capacity: 1,000 attendees
- Maximum merit points: 10,000 per gathering
- Maximum network tags: 10 per gathering

### Network Partnership Constraints
- Maximum tag length: 20 characters
- Maximum partnership multiplier: 5x
- Maximum network tags per gathering: 10

## Getting Started

### Prerequisites
- Clarity CLI tools
- Access to a Stacks blockchain node
- Understanding of POAP and NFT concepts

### Deployment Steps

1. Deploy the smart contract to your chosen network
2. Initialize network partnerships using `create-network-partnership`
3. Create your first gathering using `create-gathering`
4. Test the system with a small group of attendees

### Example Usage

1. **Creating a Network Partnership**
```clarity
(contract-call? .gather-guard create-network-partnership "ethereum" u2)
```

2. **Creating a Gathering**
```clarity
(contract-call? .gather-guard create-gathering "DevCon 2024" u1234567 u500 u100 (list "ethereum" "stacks"))
```

3. **Joining a Gathering**
```clarity
(contract-call? .gather-guard join-gathering u1)
```

## Error Handling

The contract includes comprehensive error handling with specific error codes:

- `ERR-UNAUTHORIZED (u100)`: Unauthorized access attempt
- `ERR-CAPACITY-REACHED (u101)`: Gathering is full
- `ERR-DUPLICATE-REGISTRATION (u102)`: Attendee already registered
- `ERR-INSUFFICIENT-MERITS (u103)`: Not enough merit points for redemption
- `ERR-MERIT-AWARD-FAILED (u104)`: Failed to award merit points
- `ERR-INVALID-GATHERING-PARAMS (u105)`: Invalid gathering parameters
- `ERR-NETWORK-NOT-FOUND (u106)`: Referenced network not found
- `ERR-INVALID-NETWORK-TAG (u107)`: Invalid network tag format

## Best Practices

1. **For Gathering Organizers**
   - Set realistic capacity limits based on venue size
   - Choose appropriate merit point values
   - Tag relevant networks to maximize attendee benefits
   - Plan gathering dates well in advance

2. **For Network Partners**
   - Maintain reasonable multiplier values
   - Regularly verify partnership status
   - Monitor system usage patterns

3. **For Attendees**
   - Register early to ensure spot availability
   - Track earned merit points regularly
   - Understand multiplier benefits across networks
   - Claim merits strategically

## Contributing

We welcome contributions to GatherGuard! Please follow these steps:

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## Security Considerations

- The contract includes comprehensive input validation
- Administrative functions are protected with ownership checks
- Points calculation includes overflow protection
- Network partnership multipliers are capped
- Attendance proofs are non-transferable NFTs

## Testing

The contract includes extensive testing capabilities. Run tests using:

```bash
clarinet test
```

Key test scenarios include:
- Gathering creation and management
- Attendance registration
- Merit point calculations
- Network partnership interactions
- Error condition handling

## Acknowledgments

- Proof of Attendance Protocol (POAP) concept creators
- Stacks and Clarity development community
- Contributors and early adopters

## Support

For support and questions:
- Open an issue in the repository
- Join our community Discord
- Check the documentation