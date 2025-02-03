use starknet::{ContractAddress, contract_address_const, ClassHash};
use snforge_std::{
    declare, ContractClassTrait, start_cheat_caller_address, stop_cheat_caller_address
};
use core::starknet::{ContractAddress};

use attendsys::contracts::AttenSysEvent::{IAttenSysEventDispatcher, IAttenSysEventDispatcherTrait};

fn deploy_contract(name: ByteArray, hash: ClassHash) -> ContractAddress {
    let contract = declare(name).unwrap();
    let mut constuctor_arg = ArrayTrait::new();
    let contract_owner_address: ContractAddress = contract_address_const::<'admin'>();

    contract_owner_address.serialize(ref constuctor_arg);
    hash.serialize(ref constuctor_arg);

    let (contract_address, _) = contract.deploy(@constuctor_arg).unwrap();

    contract_address
}

fn deploy_nft_contract(name: ByteArray) -> (ContractAddress, ClassHash) {
    let token_uri: ByteArray = "https://dummy_uri.com/your_id";
    let name_: ByteArray = "Attensys";
    let symbol: ByteArray = "ATS";

    let mut constructor_calldata = ArrayTrait::new();

    token_uri.serialize(ref constructor_calldata);
    name_.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);

    let contract = declare(name).unwrap();
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    (contract_address, contract.class_hash)
}

#[test]
fn test_transfer_admin() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let contract_address = deploy_contract("AttenSysEvent", hash);

    let admin: ContractAddress = contract_address_const::<'admin'>();
    let new_admin: ContractAddress = contract_address_const::<'new_admin'>();

    let attensys_event_contract = IAttenSysEventDispatcher { contract_address };

    assert(attensys_event_contract.get_admin() == admin, 'wrong admin');

    start_cheat_caller_address(contract_address, admin);

    attensys_event_contract.transfer_admin(new_admin);
    assert(attensys_event_contract.get_new_admin() == new_admin, 'wrong intended admin');

    stop_cheat_caller_address(contract_address)
}

#[test]
fn test_claim_admin() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let contract_address = deploy_contract("AttenSysEvent", hash);

    let admin: ContractAddress = contract_address_const::<'admin'>();
    let new_admin: ContractAddress = contract_address_const::<'new_admin'>();

    let attensys_course_contract = IAttenSysEventDispatcher { contract_address };

    assert(attensys_course_contract.get_admin() == admin, 'wrong admin');

    
    start_cheat_caller_address(contract_address, admin);
    attensys_course_contract.transfer_admin(new_admin);
    assert(attensys_course_contract.get_new_admin() == new_admin, 'wrong intended admin');
    stop_cheat_caller_address(contract_address);

    
    start_cheat_caller_address(contract_address, new_admin);
    attensys_course_contract.claim_admin_ownership();
    assert(attensys_course_contract.get_admin() == new_admin, 'admin claim failed');
    assert(
        attensys_course_contract.get_new_admin() == contract_address_const::<0>(),
        'admin claim failed'
    );
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: 'unauthorized caller')]
fn test_transfer_admin_should_panic_for_wrong_admin() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let contract_address = deploy_contract("AttenSysEvent", hash);

    let invalid_admin: ContractAddress = contract_address_const::<'invalid_admin'>();
    let new_admin: ContractAddress = contract_address_const::<'new_admin'>();

    let attensys_course_contract = IAttenSysEventDispatcher { contract_address };

    
    start_cheat_caller_address(contract_address, invalid_admin);
    attensys_course_contract.transfer_admin(new_admin);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: 'unauthorized caller')]
fn test_claim_admin_should_panic_for_wrong_new_admin() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let contract_address = deploy_contract("AttenSysEvent", hash);

    let admin: ContractAddress = contract_address_const::<'admin'>();
    let new_admin: ContractAddress = contract_address_const::<'new_admin'>();
    let wrong_new_admin: ContractAddress = contract_address_const::<'wrong_new_admin'>();

    let attensys_course_contract = IAttenSysEventDispatcher { contract_address };

    assert(attensys_course_contract.get_admin() == admin, 'wrong admin');

    
    start_cheat_caller_address(contract_address, admin);
    attensys_course_contract.transfer_admin(new_admin);
    stop_cheat_caller_address(contract_address);

    
    start_cheat_caller_address(contract_address, wrong_new_admin);
    attensys_course_contract.claim_admin_ownership();
    stop_cheat_caller_address(contract_address);
}

#[starknet::interface]
pub trait IAttenSysEvent<TContractState> {
    fn create_event(
        ref self: TContractState,
        owner_: ContractAddress,
        event_name: ByteArray,
        base_uri: ByteArray,
        name_: ByteArray,
        symbol: ByteArray,
        start_time_: u256,
        end_time_: u256,
        reg_status: bool,
    ) -> ContractAddress;
    fn end_event(ref self: TContractState, event_identifier: u256);
    fn batch_certify_attendees(ref self: TContractState, event_identifier: u256);
    fn mark_attendance(ref self: TContractState, event_identifier: u256);
    fn register_for_event(ref self: TContractState, event_identifier: u256);
    fn get_attendance_status(
        self: @TContractState, attendee: ContractAddress, event_identifier: u256
    ) -> bool;
    fn get_all_attended_events(
        self: @TContractState, user: ContractAddress
    ) -> Array<AttenSysEvent::UserAttendedEventStruct>;
    fn get_all_list_registered_events(
        self: @TContractState, user: ContractAddress
    ) -> Array<AttenSysEvent::UserAttendedEventStruct>;
    fn start_end_reg(ref self: TContractState, reg_stat: bool, event_identifier: u256);
    fn get_event_details(
        self: @TContractState, event_identifier: u256
    ) -> AttenSysEvent::EventStruct;
    fn get_event_nft_contract(self: @TContractState, event_identifier: u256) -> ContractAddress;
    fn get_all_events(self: @TContractState) -> Array<AttenSysEvent::EventStruct>;
    fn transfer_admin(ref self: TContractState, new_admin: ContractAddress);
    fn claim_admin_ownership(ref self: TContractState);
    fn get_admin(self: @TContractState) -> ContractAddress;
    fn get_new_admin(self: @TContractState) -> ContractAddress;
}

#[starknet::interface]
pub trait IAttenSysNft<TContractState> {
    fn mint(ref self: TContractState, recipient: ContractAddress, token_id: u256);
}

#[starknet::contract]
mod AttenSysEvent {
    use super::IAttenSysNftDispatcherTrait;
    use core::starknet::{
        ContractAddress, get_caller_address, get_block_timestamp, ClassHash,
        syscalls::deploy_syscall, contract_address_const
    };
    use core::starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Vec,
        MutableVecTrait, VecTrait
    };


    #[storage]
    struct Storage {
        all_event: Vec<EventStruct>,
        specific_event_with_identifier: Map::<u256, EventStruct>,
        attendees_registered_for_event_with_identifier: Map::<
            (u256, felt252), Vec<ContractAddress>
        >,
        event_identifier: u256,
        attendance_status: Map::<(ContractAddress, u256), bool>,
        all_registered_event_by_user: Map::<ContractAddress, Vec<UserAttendedEventStruct>>,
        all_attended_event: Map::<ContractAddress, Vec<UserAttendedEventStruct>>,
        registered: Map::<(ContractAddress, u256), bool>,
        all_attendance_marked_for_event: Map::<u256, Vec<ContractAddress>>,
        hash: ClassHash,
        admin: ContractAddress,
        intended_new_admin: ContractAddress,
        event_nft_contract_address: Map::<u256, ContractAddress>,
        track_minted_nft_id: Map::<(u256, ContractAddress), u256>,
    }

    
    #[derive(Drop, Serde, starknet::Store)]
    pub struct EventStruct {
        pub event_name: ByteArray,
        pub time: Time,
        pub active_status: bool,
        pub signature_count: u256,
        pub event_organizer: ContractAddress,
        pub registered_attendants: u256,
    }

    #[derive(Drop, Copy, Serde, starknet::Store)]
    pub struct Time {
        pub registration_open: bool,
        pub start_time: u256,
        pub end_time: u256,
    }

    #[derive(Drop, Clone, Serde, starknet::Store)]
    pub struct UserAttendedEventStruct {
        pub event_name: ByteArray,
        pub time: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, _hash: ClassHash) {
        self.admin.write(owner);
        self.hash.write(_hash);
    }
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        EventCreated: EventCreated,
        UserRegistered: UserRegistered,
        AttendanceMarked: AttendanceMarked,
        NFTMinted: NFTMinted,
    }

    #[derive(Drop, starknet::Event)]
    pub struct EventCreated {
        #[key]
        pub event_id: u32,
        pub name: felt252,
        pub organizer: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct UserRegistered {
        #[key]
        pub event_id: u32,
        #[key]
        pub user_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AttendanceMarked {
        #[key]
        pub event_id: u32,
        #[key]
        pub user_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct NFTMinted {
        #[key]
        pub event_id: u32,
        #[key]
        pub user_address: ContractAddress,
        pub nft_id: u32,
    }


    #[abi(embed_v0)]
    impl IAttenSysEventImpl of super::IAttenSysEvent<ContractState> {
        fn create_event(
            ref self: ContractState,
            owner_: ContractAddress,
            event_name: ByteArray,
            base_uri: ByteArray,
            name_: ByteArray,
            symbol: ByteArray,
            start_time_: u256,
            end_time_: u256,
            reg_status: bool,
        ) -> ContractAddress {
            let pre_existing_counter = self.event_identifier.read();
            let new_identifier = pre_existing_counter + 1;

            let time_data: Time = Time {
                registration_open: reg_status, start_time: start_time_, end_time: end_time_,
            };
            let event_call_data: EventStruct = EventStruct {
                event_name: event_name.clone(),
                time: time_data,
                active_status: true,
                signature_count: 0,
                event_organizer: owner_,
                registered_attendants: 0,
            };

            let mut constructor_args = array![];
            base_uri.serialize(ref constructor_args);
            name_.serialize(ref constructor_args);
            symbol.serialize(ref constructor_args);
            let contract_address_salt: felt252 = new_identifier.try_into().unwrap();
            let (deployed_contract_address, _) = deploy_syscall(
                self.hash.read(), contract_address_salt, constructor_args.span(), false
            )
                .expect('failed to deploy_syscall');

            self.event_nft_contract_address.entry(new_identifier).write(deployed_contract_address);

            self.all_event.append().write(event_call_data);
            self
                .specific_event_with_identifier
                .entry(new_identifier)
                .write(
                    EventStruct {
                        event_name: event_name,
                        time: time_data,
                        active_status: true,
                        signature_count: 0,
                        event_organizer: owner_,
                        registered_attendants: 0,
                    }
                );
            self.event_identifier.write(new_identifier);
            self.track_minted_nft_id.entry((new_identifier, deployed_contract_address)).write(1);
            self.emit(EventCreated { event_id, name, organizer });
            self.emit(Event::EventCreated(EventCreated { event_id, name, organizer }));
            deployed_contract_address
        
        }

        fn end_event(ref self: ContractState, event_identifier: u256) {
            self.end_event_(event_identifier);
        }

        fn batch_certify_attendees(ref self: ContractState, event_identifier: u256) {
            let event_details = self.specific_event_with_identifier.entry(event_identifier).read();
            assert(event_details.event_organizer == get_caller_address(), 'not authorized');
            if self.all_attendance_marked_for_event.entry(event_identifier).len() > 0 {
                let nft_contract_address = self
                    .event_nft_contract_address
                    .entry(event_identifier)
                    .read();
                for i in 0
                    ..self
                        .all_attendance_marked_for_event
                        .entry(event_identifier)
                        .len() {
                            self
                                .attendance_status
                                .entry(
                                    (
                                        self
                                            .all_attendance_marked_for_event
                                            .entry(event_identifier)
                                            .at(i)
                                            .read(),
                                        event_identifier
                                    )
                                )
                                .write(true);
                            let nft_dispatcher = super::IAttenSysNftDispatcher {
                                contract_address: nft_contract_address
                            };

                            let nft_id = self
                                .track_minted_nft_id
                                .entry((event_identifier, nft_contract_address))
                                .read();
                            nft_dispatcher
                                .mint(
                                    self
                                        .all_attendance_marked_for_event
                                        .entry(event_identifier)
                                        .at(i)
                                        .read(),
                                    nft_id
                                );
                            self
                                .track_minted_nft_id
                                .entry((event_identifier, nft_contract_address))
                                .write(nft_id + 1);
                        }
            }
        }

        fn mark_attendance(ref self: ContractState, event_identifier: u256) {
            let event_details = self.specific_event_with_identifier.entry(event_identifier).read();
            assert(
                self.registered.entry((get_caller_address(), event_identifier)).read() == true,
                'not registered'
            );
            assert(event_details.active_status == true, 'not started');
            assert(get_block_timestamp().into() >= event_details.time.start_time, 'not started');
            let count = self
                .specific_event_with_identifier
                .entry(event_identifier)
                .signature_count
                .read();
            self
                .specific_event_with_identifier
                .entry(event_identifier)
                .signature_count
                .write(count + 1);

            if self.all_event.len() > 0 {
                for i in 0
                    ..self
                        .all_event
                        .len() {
                            if self.all_event.at(i).read().event_name == event_details.event_name {
                                self.all_event.at(i).signature_count.write(count + 1);
                            }
                        }
            }
            self
                .all_attendance_marked_for_event
                .entry(event_identifier)
                .append()
                .write(get_caller_address());
            let call_data = UserAttendedEventStruct {
                event_name: event_details.event_name, time: event_details.time.start_time,
            };
            self.all_attended_event.entry(get_caller_address()).append().write(call_data);
            self.emit(AttendanceMarked { event_id, user_address });
            self.emit(Event::AttendanceMarked(AttendanceMarked { event_id, user_address }));
        }

        fn register_for_event(ref self: ContractState, event_identifier: u256) {
            let event_details = self.specific_event_with_identifier.entry(event_identifier).read();
            assert(
                self.registered.entry((get_caller_address(), event_identifier)).read() == false,
                'already registered'
            );
            assert(get_block_timestamp().into() >= event_details.time.start_time, 'not started');
            self.registered.entry((get_caller_address(), event_identifier)).write(true);

            let count = self
                .specific_event_with_identifier
                .entry(event_identifier)
                .registered_attendants
                .read();
            self
                .specific_event_with_identifier
                .entry(event_identifier)
                .registered_attendants
                .write(count + 1);

            if self.all_event.len() > 0 {
                for i in 0
                    ..self
                        .all_event
                        .len() {
                            if self.all_event.at(i).read().event_name == event_details.event_name {
                                self.all_event.at(i).registered_attendants.write(count + 1);
                            }
                        }
            }
            let call_data = UserAttendedEventStruct {
                event_name: event_details.event_name, time: event_details.time.start_time,
            };
            self.all_registered_event_by_user.entry(get_caller_address()).append().write(call_data);
        }

        fn get_attendance_status(
            self: @ContractState, attendee: ContractAddress, event_identifier: u256
        ) -> bool {
            self.attendance_status.entry((attendee, event_identifier)).read()
        }

        fn get_all_attended_events(
            self: @ContractState, user: ContractAddress
        ) -> Array<UserAttendedEventStruct> {
            let vec = self.all_attended_event.entry(user);
            let mut arr = array![];
            let len = vec.len();
            let mut i: u64 = 0;

            loop {
                if i >= len {
                    break;
                }
                if let Option::Some(element) = vec.get(i) {
                    arr.append(element.read());
                }
                i += 1;
            };

            arr
        }

        fn get_all_list_registered_events(
            self: @ContractState, user: ContractAddress
        ) -> Array<UserAttendedEventStruct> {
            let mut arr = array![];
            let vec = self.all_registered_event_by_user.entry(user);
            let len = vec.len();
            let mut i: u64 = 0;

            loop {
                if i >= len {
                    break;
                }
                if let Option::Some(element) = vec.get(i) {
                    arr.append(element.read());
                }
                i += 1;
            };

            arr
        }

        fn start_end_reg(ref self: ContractState, reg_stat: bool, event_identifier: u256) {
            let event_details = self.specific_event_with_identifier.entry(event_identifier).read();
            assert(event_details.event_organizer == get_caller_address(), 'not authorized');
            self
                .specific_event_with_identifier
                .entry(event_identifier)
                .time
                .registration_open
                .write(reg_stat);
            if self.all_event.len() > 0 {
                for i in 0
                    ..self
                        .all_event
                        .len() {
                            if self.all_event.at(i).read().event_name == event_details.event_name {
                                self.all_event.at(i).time.registration_open.write(reg_stat);
                            }
                        }
            }
        }

        fn get_event_details(self: @ContractState, event_identifier: u256) -> EventStruct {
            self.specific_event_with_identifier.entry(event_identifier).read()
        }
        fn get_event_nft_contract(self: @ContractState, event_identifier: u256) -> ContractAddress {
            self.event_nft_contract_address.entry(event_identifier).read()
        }

        fn get_all_events(self: @ContractState) -> Array<EventStruct> {
            let mut arr = array![];
            for i in 0..self.all_event.len() {
                arr.append(self.all_event.at(i).read());
            };
            arr
        }

        fn transfer_admin(ref self: ContractState, new_admin: ContractAddress) {
            assert(new_admin != self.zero_address(), 'zero address not allowed');
            assert(get_caller_address() == self.admin.read(), 'unauthorized caller');

            self.intended_new_admin.write(new_admin);
        }

        fn claim_admin_ownership(ref self: ContractState) {
            assert(get_caller_address() == self.intended_new_admin.read(), 'unauthorized caller');

            self.admin.write(self.intended_new_admin.read());
            self.intended_new_admin.write(self.zero_address());
        }

        fn get_admin(self: @ContractState) -> ContractAddress {
            self.admin.read()
        }

        fn get_new_admin(self: @ContractState) -> ContractAddress {
            self.intended_new_admin.read()
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn end_event_(ref self: ContractState, event_identifier: u256) {
            let event_details = self.specific_event_with_identifier.entry(event_identifier).read();
            assert(event_details.event_organizer == get_caller_address(), 'not authorized');

            let time_data: Time = Time {
                registration_open: false, start_time: event_details.time.start_time, end_time: 0,
            };
            self.specific_event_with_identifier.entry(event_identifier).time.write(time_data);
            self.specific_event_with_identifier.entry(event_identifier).active_status.write(false);
            if self.all_event.len() > 0 {
                for i in 0
                    ..self
                        .all_event
                        .len() {
                            if self.all_event.at(i).read().event_name == event_details.event_name {
                                self.all_event.at(i).time.write(time_data);
                                self.all_event.at(i).active_status.write(false);
                            }
                        }
            }
        }

        fn zero_address(self: @ContractState) -> ContractAddress {
            contract_address_const::<0>()
        }
    }
}
