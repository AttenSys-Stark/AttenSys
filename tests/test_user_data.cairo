use snforge_std::{ declare, ContractClassTrait, start_cheat_caller_address, stop_cheat_caller_address };
use starknet::{ ContractAddress, contract_address_const };
use attendsys::contracts::data::{ AttensysUserData, IAttensysUserDataDispatcher, IAttensysUserDataDispatcherTrait };

fn deploy_contract() -> ContractAddress {

    let contract = declare("AttensysUserData").unwrap();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    contract_address
}

#[test]
fn test_create_name() {
    let contract_address = deploy_contract();
    let dispatcher = IAttensysUserDataDispatcher { contract_address };
    let caller = contract_address_const::<'caller'>();

    start_cheat_caller_address(contract_address, caller);
    dispatcher.create_name('firstname', 'Qed85tyuu45ggtCfG6hy');
    stop_cheat_caller_address(contract_address);

    let user = dispatcher.get_specific_user(caller);
    assert!(user.name == 'firstname', "Not stored user name");
}

#[test]
#[should_panic(expected: 'Invalid name or uri')]
fn test_create_name_should_panic() {
    let contract_address = deploy_contract();
    let dispatcher = IAttensysUserDataDispatcher { contract_address };
    let caller = contract_address_const::<'caller'>();

    start_cheat_caller_address(contract_address, caller);
    dispatcher.create_name('', 'Qed85tyuu45ggtCfG6hy');
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: 'name already taken')]
fn test_create_name_should_panic_name_already_taken() {
    let contract_address = deploy_contract();
    let dispatcher = IAttensysUserDataDispatcher { contract_address };
    let caller = contract_address_const::<'caller'>();
    let caller2 = contract_address_const::<'caller2'>();

    start_cheat_caller_address(contract_address, caller);
    dispatcher.create_name('firstname', 'Qed85tyuu45ggtCfG6hy');
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, caller2);
    dispatcher.create_name('firstname', 'Qed85tyuu45ggtCfG6hy');
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_get_all_users() {
    let contract_address = deploy_contract();
    let dispatcher = IAttensysUserDataDispatcher { contract_address };
    let caller = contract_address_const::<'caller'>();
    let caller2 = contract_address_const::<'caller2'>();

    start_cheat_caller_address(contract_address, caller);
    dispatcher.create_name('first_user', 'Qed85tyuu45ggtCfG6hy');
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, caller2);
    dispatcher.create_name('second_user', 'Qed85tyuu45ggtCfG6hy');
    stop_cheat_caller_address(contract_address);

    let all_users = dispatcher.get_all_users();
    let name1 = all_users[0].name;
    let name2 = all_users[1].name;
    assert(all_users.len() == 2, 'Inaccurate no of users');
    assert(name1 == 'first_user', 'Not first user name');
    assert(name1 == 'second_user', 'Not second user');
}