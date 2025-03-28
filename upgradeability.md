# AttenSys Contracts Upgradeability

This document outlines the upgrade mechanism implemented for the AttenSys contracts.

## Overview

The AttenSys contracts have been modified to support upgrades while maintaining backward compatibility. This allows for future enhancements without redeploying new contract addresses, preserving existing contract data and functionality.

# Upgrade Mechanism

## Implementation Details
Each contract now includes:

**Upgrade Interface** : A standard interface that exposes the upgrade functionality.

```cairo
#[starknet::interface]
pub trait IUpgradeable<TContractState> {
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
}
```

**Upgrade Function** : The implementation that allows authorized administrators to replace the contract's implementation.

```cairo
#[abi(embed_v0)]
impl UpgradeableImpl of super::IUpgradeable<ContractState> {
    fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
        // Only admin can upgrade the contract
        let caller = get_caller_address();
        assert(caller == self.admin.read(), 'unauthorized caller');
        
        // Make sure the new implementation isn't zero
        assert(!new_class_hash.is_zero(), 'New class hash cannot be zero');
        
        // Get current contract class hash
        let current_class_hash = starknet::syscalls::get_contract_address()
            .class_hash_at(contract_address_const::<0>()).unwrap();
        
        // Make sure we are not "upgrading" to the same implementation
        assert(current_class_hash != new_class_hash, 'Cannot upgrade to same class');
        
        // Perform the upgrade
        replace_class_syscall(new_class_hash).expect('Upgrade failed');
        
        // Emit event
        self.emit(ContractUpgraded { 
            old_class_hash: current_class_hash,
            new_class_hash: new_class_hash 
        });
    }
}
```

**Upgrade Event**: An event that is emitted when a contract is upgraded.

```cairo
#[derive(Drop, starknet::Event)]
pub struct ContractUpgraded {
    pub old_class_hash: ClassHash,
    pub new_class_hash: ClassHash,
}
```

## Access Control

Only the contract administrator can perform upgrades. This is enforced in the upgrade function with the following check:
```cairo
assert(caller == self.admin.read(), 'unauthorized caller');
```

## Storage Layout Consistency

When upgrading contracts, it is critical to maintain the same storage layout to prevent data corruption. The storage layout in all AttenSys contracts has been carefully structured to be backward compatible:

- No existing storage variables have been removed.
- New storage variables, if any, must be added at the end of the existing storage layout.
- The types of existing storage variables must remain unchanged.

## Upgrade Process

The upgrade process follows these steps:

- Deploy the new implementation as a StarkNet class (this will give you a new class hash).
- Call the upgrade function on the existing contract, passing the new class hash as a parameter.
- The contract checks that the caller is authorized and performs the upgrade.
- After the upgrade, the contract will use the new implementation while preserving all existing data.

This is how it works;

```cairo
// Using a dispatcher to call the upgrade function
let upgrade_dispatcher = IUpgradeableDispatcher { contract_address };
upgrade_dispatcher.upgrade(new_class_hash);
```