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
    fn sponsor_event(ref self: TContractState, event: ContractAddress, amt: u256, uri: ByteArray);
    fn withdraw_sponsorship_funds(ref self: TContractState, amt: u256);
}

#[starknet::interface]
pub trait IAttenSysNft<TContractState> {
    // NFT contract
    fn mint(ref self: TContractState, recipient: ContractAddress, token_id: u256);
}

#[starknet::contract]
mod AttenSysEvent {
    use core::num::traits::Zero;
    use super::IAttenSysNftDispatcherTrait;
    use core::starknet::{
        ContractAddress, get_caller_address, get_block_timestamp, ClassHash,
        syscalls::deploy_syscall, contract_address_const
    };
    use core::starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Vec,
        MutableVecTrait, VecTrait
    };
    use attendsys::contracts::AttenSysSponsor::{
        IAttenSysSponsorDispatcher, IAttenSysSponsorDispatcherTrait
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
        // event to balance_of_sponsorship
        event_to_balance_of_sponsorship: Map::<ContractAddress, u256>,
        // event to list of sponsors
        event_to_list_of_sponsors: Map::<ContractAddress, Vec<ContractAddress>>,
        // the currency used on the platform
        token_address: ContractAddress,
        // sponsorship contract address
        sponsorship_contract_address: ContractAddress,
        // tracks existing events
        event_exists: Map::<ContractAddress, bool>
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

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Sponsor: Sponsor,
        Withdrawn: Withdrawn
    }

    #[derive(Drop, starknet::Event)]
    pub struct Sponsor {
        pub amt: u256,
        pub uri: ByteArray,
        #[key]
        pub event: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Withdrawn {
        pub amt: u256,
        #[key]
        pub event: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        _hash: ClassHash,
        _token_address: ContractAddress,
        sponsorship_contract_address: ContractAddress
    ) {
        self.admin.write(owner);
        self.hash.write(_hash);
        self.token_address.write(_token_address);
        self.sponsorship_contract_address.write(sponsorship_contract_address);
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
            self.event_exists.entry(owner_).write(true);
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

        fn sponsor_event(
            ref self: ContractState, event: ContractAddress, amt: u256, uri: ByteArray
        ) {
            assert(!event.is_zero(), 'not an event');
            assert(uri.len() > 0, 'uri is empty');
            // check if such event exists
            assert(self.event_exists.entry(event).read(), 'No such event');
            assert(amt > 0, 'Invalid amount');
            let sponsor = get_caller_address();
            let balance = self.event_to_balance_of_sponsorship.entry(event).read();
            let sponsor_contract_address = self.sponsorship_contract_address.read();
            let token_address = self.token_address.read();
            let sponsor_dispatcher = IAttenSysSponsorDispatcher {
                contract_address: sponsor_contract_address
            };
            sponsor_dispatcher.deposit(token_address, amt);
            self.event_to_balance_of_sponsorship.entry(event).write(balance + amt);

            // verify if sponsor doesn't already exist
            let mut existing_sponsors = self.event_to_list_of_sponsors.entry(event);
            let mut sponsor_exists = false;
            for i in 0
                ..existing_sponsors
                    .len() {
                        if sponsor == existing_sponsors.at(i).read() {
                            sponsor_exists = true;
                            break;
                        }
                    };

            if !sponsor_exists {
                existing_sponsors.append().write(sponsor);
            }

            self.emit(Sponsor { amt, uri, event });
        }

        fn withdraw_sponsorship_funds(ref self: ContractState, amt: u256) {
            let event = get_caller_address();
            assert(self.event_exists.entry(event).read(), 'No such event');
            let event_sponsorship_balance = self
                .event_to_balance_of_sponsorship
                .entry(event)
                .read();
            assert(event_sponsorship_balance > 0, 'Zero funds retrieved');
            assert(event_sponsorship_balance >= amt, 'Insufficient funds');
            let token_address = self.token_address.read();
            let sponsor_contract_address = self.sponsorship_contract_address.read();
            let sponsor_dispatcher = IAttenSysSponsorDispatcher {
                contract_address: sponsor_contract_address
            };
            sponsor_dispatcher.withdraw(token_address, amt);
            self
                .event_to_balance_of_sponsorship
                .entry(event)
                .write(event_sponsorship_balance - amt);

            self.emit(Withdrawn { amt, event });
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
