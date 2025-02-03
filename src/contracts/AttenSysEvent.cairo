use core::starknet::{ContractAddress};

//@todo : return the nft id and token uri in the get functions

//@todo look into computing an hash passcode, pass it in as an argument (at the point of creating
//event), and make sure this hash can be confirmed.

#[starknet::interface]
pub trait IAttenSysEvent<TContractState> {
    //implement a paid event feature in the create_event & implement a register for event function
    //that takes into consideration payment factor
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
    //@todo fn get_registered_users(ref self: TContractState, event_identifier : u256, passcode :
    // felt252) -> Array<ContractAddress>;
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
    // NFT contract
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
        //saves all event
        all_event: Vec<EventStruct>,
        //saves specific event
        specific_event_with_identifier: Map::<u256, EventStruct>,
        //saves attendees details that reg for a particular event, use an admin passcode that can be
        //hashed to protect this information
        attendees_registered_for_event_with_identifier: Map::<
            (u256, felt252), Vec<ContractAddress>
        >,
        //event identifier
        event_identifier: u256,
        //saves attendance status
        attendance_status: Map::<(ContractAddress, u256), bool>,
        //saves user registered event
        all_registered_event_by_user: Map::<ContractAddress, Vec<UserAttendedEventStruct>>,
        //saves all attended events
        all_attended_event: Map::<ContractAddress, Vec<UserAttendedEventStruct>>,
        //saves registraction status
        registered: Map::<(ContractAddress, u256), bool>,
        //save the actual addresses that marked attendance
        all_attendance_marked_for_event: Map::<u256, Vec<ContractAddress>>,
        //nft classhash
        hash: ClassHash,
        //admin address
        admin: ContractAddress,
        // address of intended new admin
        intended_new_admin: ContractAddress,
        //saves nft contract address associated to event
        event_nft_contract_address: Map::<u256, ContractAddress>,
        //tracks all minted nft id minted by events
        track_minted_nft_id: Map::<(u256, ContractAddress), u256>,
    }

    //create a separate struct for the all_attended_event that will only have the time the event
    //took place and its name
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

            // constructor arguments
            let mut constructor_args = array![];
            base_uri.serialize(ref constructor_args);
            name_.serialize(ref constructor_args);
            symbol.serialize(ref constructor_args);
            let contract_address_salt: felt252 = new_identifier.try_into().unwrap();
            //deploy contract
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
            deployed_contract_address
        }

        fn end_event(ref self: ContractState, event_identifier: u256) {
            //only event owner
            self.end_event_(event_identifier);
        }

        fn batch_certify_attendees(ref self: ContractState, event_identifier: u256) {
            //only event owner
            let event_details = self.specific_event_with_identifier.entry(event_identifier).read();
            assert(event_details.event_organizer == get_caller_address(), 'not authorized');
            //update attendance_status here
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
        }

        fn register_for_event(ref self: ContractState, event_identifier: u256) {
            let event_details = self.specific_event_with_identifier.entry(event_identifier).read();
            //can only register once
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

        //@todo fn get_registered_users(ref self: ContractState, event_identifier : u256, passcode :
        // felt252 ) -> Array<ContractAddress>{

        // }

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
            //only event owner
            assert(event_details.event_organizer == get_caller_address(), 'not authorized');
            self
                .specific_event_with_identifier
                .entry(event_identifier)
                .time
                .registration_open
                .write(reg_stat);
            //loop through the all_event vec and end the specific event
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
            //only event owner
            assert(event_details.event_organizer == get_caller_address(), 'not authorized');

            let time_data: Time = Time {
                registration_open: false, start_time: event_details.time.start_time, end_time: 0,
            };
            //reset specific event with identifier
            self.specific_event_with_identifier.entry(event_identifier).time.write(time_data);
            self.specific_event_with_identifier.entry(event_identifier).active_status.write(false);
            //loop through the all_event vec and end the specific event
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

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        EventCreated: EventCreated,
        EventEnded: EventEnded,
        AttendeesCertified: AttendeesCertified,
        AttendanceMarked: AttendanceMarked,
        RegisteredForEvent: RegisteredForEvent,
        RegistrationStatusChanged: RegistrationStatusChanged,
        AdminTransferred: AdminTransferred,
        AdminOwnershipClaimed: AdminOwnershipClaimed,
    }

    #[derive(Drop, starknet::Event)]
    pub struct EventCreated {
        pub event_identifier: u256,
        pub owner: ContractAddress,
        pub event_name: ByteArray,
        pub base_uri: ByteArray,
        pub name: ByteArray,
        pub symbol: ByteArray,
        pub start_time: u256,
        pub end_time: u256,
        pub reg_status: bool,
        pub nft_contract_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct EventEnded {
        pub event_identifier: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AttendeesCertified {
        pub event_identifier: u256,
        pub attendees: Array<ContractAddress>,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AttendanceMarked {
        pub event_identifier: u256,
        pub attendee: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RegisteredForEvent {
        pub event_identifier: u256,
        pub attendee: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RegistrationStatusChanged {
        pub event_identifier: u256,
        pub reg_status: bool,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AdminTransferred {
        pub new_admin: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AdminOwnershipClaimed {
        pub new_admin: ContractAddress,
    }

    #[storage]
    struct Storage {
        all_event: Vec<EventStruct>,
        specific_event_with_identifier: Map::<u256, EventStruct>,
        attendees_registered_for_event_with_identifier: Map::<(u256, felt252), Vec<ContractAddress>>,
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
            ).expect('failed to deploy_syscall');

            self.event_nft_contract_address.entry(new_identifier).write(deployed_contract_address);

            self.all_event.append().write(event_call_data);
            self.specific_event_with_identifier.entry(new_identifier).write(
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

            self.emit(EventCreated {
                event_identifier: new_identifier,
                owner: owner_,
                event_name: event_name,
                base_uri: base_uri,
                name: name_,
                symbol: symbol,
                start_time: start_time_,
                end_time: end_time_,
                reg_status: reg_status,
                nft_contract_address: deployed_contract_address,
            });

            deployed_contract_address
        }

        fn end_event(ref self: ContractState, event_identifier: u256) {
            self.end_event_(event_identifier);
            self.emit(EventEnded { event_identifier });
        }

        fn batch_certify_attendees(ref self: ContractState, event_identifier: u256) {
            let event_details = self.specific_event_with_identifier.entry(event_identifier).read();
            assert(event_details.event_organizer == get_caller_address(), 'not authorized');

            if self.all_attendance_marked_for_event.entry(event_identifier).len() > 0 {
                let nft_contract_address = self.event_nft_contract_address.entry(event_identifier).read();
                let mut attendees = array![];
                for i in 0..self.all_attendance_marked_for_event.entry(event_identifier).len() {
                    let attendee = self.all_attendance_marked_for_event.entry(event_identifier).at(i).read();
                    self.attendance_status.entry((attendee, event_identifier)).write(true);
                    let nft_dispatcher = super::IAttenSysNftDispatcher { contract_address: nft_contract_address };
                    let nft_id = self.track_minted_nft_id.entry((event_identifier, nft_contract_address)).read();
                    nft_dispatcher.mint(attendee, nft_id);
                    self.track_minted_nft_id.entry((event_identifier, nft_contract_address)).write(nft_id + 1);
                    attendees.append(attendee);
                }
                self.emit(AttendeesCertified { event_identifier, attendees });
            }
        }

        fn mark_attendance(ref self: ContractState, event_identifier: u256) {
            let event_details = self.specific_event_with_identifier.entry(event_identifier).read();
            assert(self.registered.entry((get_caller_address(), event_identifier)).read() == true, 'not registered');
            assert(event_details.active_status == true, 'not started');
            assert(get_block_timestamp().into() >= event_details.time.start_time, 'not started');

            let count = self.specific_event_with_identifier.entry(event_identifier).signature_count.read();
            self.specific_event_with_identifier.entry(event_identifier).signature_count.write(count + 1);

            if self.all_event.len() > 0 {
                for i in 0..self.all_event.len() {
                    if self.all_event.at(i).read().event_name == event_details.event_name {
                        self.all_event.at(i).signature_count.write(count + 1);
                    }
                }
            }

            self.all_attendance_marked_for_event.entry(event_identifier).append().write(get_caller_address());
            let call_data = UserAttendedEventStruct {
                event_name: event_details.event_name, time: event_details.time.start_time,
            };
            self.all_attended_event.entry(get_caller_address()).append().write(call_data);

            self.emit(AttendanceMarked { event_identifier, attendee: get_caller_address() });
        }

        fn register_for_event(ref self: ContractState, event_identifier: u256) {
            let event_details = self.specific_event_with_identifier.entry(event_identifier).read();
            assert(self.registered.entry((get_caller_address(), event_identifier)).read() == false, 'already registered');
            assert(get_block_timestamp().into() >= event_details.time.start_time, 'not started');

            self.registered.entry((get_caller_address(), event_identifier)).write(true);

            let count = self.specific_event_with_identifier.entry(event_identifier).registered_attendants.read();
            self.specific_event_with_identifier.entry(event_identifier).registered_attendants.write(count + 1);

            if self.all_event.len() > 0 {
                for i in 0..self.all_event.len() {
                    if self.all_event.at(i).read().event_name == event_details.event_name {
                        self.all_event.at(i).registered_attendants.write(count + 1);
                    }
                }
            }

            let call_data = UserAttendedEventStruct {
                event_name: event_details.event_name, time: event_details.time.start_time,
            };
            self.all_registered_event_by_user.entry(get_caller_address()).append().write(call_data);

            self.emit(RegisteredForEvent { event_identifier, attendee: get_caller_address() });
        }

        fn start_end_reg(ref self: ContractState, reg_stat: bool, event_identifier: u256) {
            let event_details = self.specific_event_with_identifier.entry(event_identifier).read();
            assert(event_details.event_organizer == get_caller_address(), 'not authorized');

            self.specific_event_with_identifier.entry(event_identifier).time.registration_open.write(reg_stat);

            if self.all_event.len() > 0 {
                for i in 0..self.all_event.len() {
                    if self.all_event.at(i).read().event_name == event_details.event_name {
                        self.all_event.at(i).time.registration_open.write(reg_stat);
                    }
                }
            }

            self.emit(RegistrationStatusChanged { event_identifier, reg_status: reg_stat });
        }

        fn transfer_admin(ref self: ContractState, new_admin: ContractAddress) {
            assert(new_admin != self.zero_address(), 'zero address not allowed');
            assert(get_caller_address() == self.admin.read(), 'unauthorized caller');

            self.intended_new_admin.write(new_admin);
            self.emit(AdminTransferred { new_admin });
        }

        fn claim_admin_ownership(ref self: ContractState) {
            assert(get_caller_address() == self.intended_new_admin.read(), 'unauthorized caller');

            self.admin.write(self.intended_new_admin.read());
            self.intended_new_admin.write(self.zero_address());
            self.emit(AdminOwnershipClaimed { new_admin: self.admin.read() });
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
                for i in 0..self.all_event.len() {
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