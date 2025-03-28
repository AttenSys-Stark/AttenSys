#[cfg(test)]
mod tests {
    use core::traits::TryInto;
    use array::ArrayTrait;
    use core::result::ResultTrait;
    use option::OptionTrait;
    use traits::Into;
    use starknet::{
        ContractAddress, syscalls::deploy_syscall, class_hash::Felt252TryIntoClassHash,
        contract_address_const, testing::{set_contract_address, set_caller_address},
    };
    use starknet::class_hash::ClassHash;
    use starknet::syscalls::replace_class_syscall;

    use attendsys::contracts::AttenSysOrg::{
        AttenSysOrg, IAttenSysOrgDispatcher, IAttenSysOrgDispatcherTrait
    };
    
    use attendsys::contracts::AttenSysOrg::{
        IUpgradeableDispatcher, IUpgradeableDispatcherTrait
    };

    // Constants for testing
    const ADMIN_ADDRESS: felt252 = 0x123;
    const USER_ADDRESS: felt252 = 0x456;
    const CLASS_HASH: felt252 = 0x789;
    const TOKEN_ADDRESS: felt252 = 0xabc;
    const SPONSOR_CONTRACT_ADDRESS: felt252 = 0xdef;
    const NEW_CLASS_HASH: felt252 = 0x111;

    fn deploy_attensys_org() -> ContractAddress {
        let mut calldata = ArrayTrait::new();
        calldata.append(ADMIN_ADDRESS); // admin
        calldata.append(CLASS_HASH); // class_hash
        calldata.append(TOKEN_ADDRESS); // token_address
        calldata.append(SPONSOR_CONTRACT_ADDRESS); // sponsorship_contract_address

        let (address, _) = deploy_syscall(
            AttenSysOrg::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
        ).unwrap();

        address
    }

    #[test]
    fn test_upgrade_attensys_org() {
        let contract_address = deploy_attensys_org();
        
        let org_dispatcher = IAttenSysOrgDispatcher { contract_address };
        let upgrade_dispatcher = IUpgradeableDispatcher { contract_address };
        
        assert(org_dispatcher.get_admin() == contract_address_const::<ADMIN_ADDRESS>(), 'Admin should be set correctly');
        
        set_caller_address(contract_address_const::<ADMIN_ADDRESS>());
        
        upgrade_dispatcher.upgrade(NEW_CLASS_HASH.try_into().unwrap());
        
    }

    #[test]
    #[should_panic(expected: ('unauthorized caller',))]
    fn test_upgrade_attensys_org_unauthorized() {
        let contract_address = deploy_attensys_org();
        
        let upgrade_dispatcher = IUpgradeableDispatcher { contract_address };
        
        set_caller_address(contract_address_const::<USER_ADDRESS>());
        
        upgrade_dispatcher.upgrade(NEW_CLASS_HASH.try_into().unwrap());
    }

    #[test]
    #[should_panic(expected: ('New class hash cannot be zero',))]
    fn test_upgrade_attensys_org_zero_class_hash() {
        let contract_address = deploy_attensys_org();
        
        let upgrade_dispatcher = IUpgradeableDispatcher { contract_address };
        
        set_caller_address(contract_address_const::<ADMIN_ADDRESS>());
        
        upgrade_dispatcher.upgrade(0.try_into().unwrap());
    }
}