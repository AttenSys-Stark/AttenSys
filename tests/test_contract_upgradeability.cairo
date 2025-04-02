use starknet::{ContractAddress, contract_address_const, ClassHash, get_caller_address};
use snforge_std::{
    declare, ContractClassTrait, start_cheat_caller_address, 
    spy_events, EventSpyAssertionsTrait, test_address, 
    stop_cheat_caller_address,
};
use attendsys::contracts::AttenSysOrg::{
    AttenSysOrg, 
    IAttenSysOrgDispatcher, 
    IAttenSysOrgDispatcherTrait,
    IUpgradeableDispatcher, 
    IUpgradeableDispatcherTrait,
    ContractUpgraded
};

fn deploy_attensys_org() -> (ContractAddress, ContractAddress) {
    let org_address: ContractAddress = contract_address_const::<'contract_owner_address'>();
    
    let mut constructor_arg = ArrayTrait::new();
    org_address.serialize(ref constructor_arg);
    
    let class_hash: felt252 = 0x789;
    let token_address: ContractAddress = contract_address_const::<'token_address'>();
    let sponsor_contract_address: ContractAddress = contract_address_const::<'sponsor_address'>();
    
    class_hash.serialize(ref constructor_arg);
    token_address.serialize(ref constructor_arg);
    sponsor_contract_address.serialize(ref constructor_arg);
    let org_contract = declare("AttenSysOrg").unwrap();
    let (contract_address, _) = org_contract.deploy(@constructor_arg).unwrap();
    
    (contract_address, org_address)
}

#[test]
fn test_upgrade_attensys_org() {
    let (contract_address, admin_address) = deploy_attensys_org();
    
    let org_dispatcher = IAttenSysOrgDispatcher { contract_address };
    let upgrade_dispatcher = IUpgradeableDispatcher { contract_address };
    
    start_cheat_caller_address(contract_address, admin_address);
    
    // Original class hash from deployment
    let original_class_hash: felt252 = 0x789;
    
    // New class hash for upgrade
    let new_class_hash: ClassHash = 0x111.try_into().unwrap();
    
    let mut spy = spy_events();
    
    upgrade_dispatcher.upgrade(new_class_hash);
    
    // Check for the ContractUpgraded event
    spy.assert_emitted(
        @array![(
            contract_address, 
            @array![ContractUpgraded { 
                old_class_hash: original_class_hash, 
                new_class_hash 
            }]
        )]
    );
}

#[test]
#[should_panic(expected: ('unauthorized caller',))]
fn test_upgrade_attensys_org_unauthorized() {
    let (contract_address, admin_address) = deploy_attensys_org();
    
    let upgrade_dispatcher = IUpgradeableDispatcher { contract_address };
    
    let unauthorized_user: ContractAddress = contract_address_const::<'unauthorized_user'>();
    start_cheat_caller_address(contract_address, unauthorized_user);
    
    let new_class_hash: ClassHash = 0x111.try_into().unwrap();
    
    upgrade_dispatcher.upgrade(new_class_hash);
}

#[test]
#[should_panic(expected: ('New class hash cannot be zero',))]
fn test_upgrade_attensys_org_zero_class_hash() {
    let (contract_address, admin_address) = deploy_attensys_org();
    
    let upgrade_dispatcher = IUpgradeableDispatcher { contract_address };
    
    start_cheat_caller_address(contract_address, admin_address);
    
    let zero_class_hash: ClassHash = 0.try_into().unwrap();
    
    upgrade_dispatcher.upgrade(zero_class_hash);
}