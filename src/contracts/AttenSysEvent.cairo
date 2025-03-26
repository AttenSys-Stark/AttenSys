use core::starknet::{ContractAddress};

use attendsys::contracts::modules::common::{EventStruct as ModuleEventStruct, Time as ModuleTime, EventCreated, EventEnded, RegistrationStatusChanged};
use attendsys::contracts::modules::event_management::event_manager;

//@todo : return the nft id and token uri in the get functions
#[starknet::interface]
pub trait IAttenSysEvent<TContractState> {
    // Core event management functions
    fn create_event(
        ref self: TContractState,
        owner_: ContractAddress,
        event_name: ByteArray,
        base_uri: ByteArray,
        name_: ByteArray,
        symbol: ByteArray,
        start_time_: u256,
        end_time_: u256,
        reg_status: u8,
        event_uri: ByteArray,
        event_location : u8,
    ) -> ContractAddress;
    
    fn end_event(ref self: TContractState, event_identifier: u256);
    fn start_end_reg(ref self: TContractState, reg_stat: u8, event_identifier: u256);
    fn cancel_event(ref self: TContractState, event_identifier: u256);
    
    // Event query functions
    fn get_event_details(self: @TContractState, event_identifier: u256) -> AttenSysEvent::EventStruct;
    fn get_all_events(self: @TContractState) -> Array<AttenSysEvent::EventStruct>;
    fn get_all_created_events(self: @TContractState, organizer: ContractAddress) -> Array<AttenSysEvent::EventStruct>;
    fn get_event_nft_contract(self: @TContractState, event_identifier: u256) -> ContractAddress;
    fn get_cancelation_status(self: @TContractState, event_identifier : u256)-> bool;
    fn get_if_registration_is_open(self: @TContractState, event_identifier : u256)-> u8;
    fn get_event_suspended_status(self: @TContractState, event_identifier: u256) -> bool;

    // Attendance functions
    fn batch_certify_attendees(ref self: TContractState, event_identifier: u256);
    fn mark_attendance(ref self: TContractState, event_identifier: u256, attendee_ : ContractAddress);
    fn register_for_event(ref self: TContractState, event_identifier: u256, user_uri : ByteArray);
    fn get_registered_users(self: @TContractState, event_identifier : u256) -> Array<AttenSysEvent::AttendeeInfo>;
    fn get_attendance_status(self: @TContractState, attendee: ContractAddress, event_identifier: u256) -> bool;
    fn get_all_attended_events(self: @TContractState, user: ContractAddress) -> Array<AttenSysEvent::UserAttendedEventStruct>;
    fn get_all_list_registered_events(self: @TContractState, user: ContractAddress) -> Array<AttenSysEvent::UserAttendedEventStruct>;
    fn get_all_attendace_marked(self: @TContractState, event_identifier : u256) -> Array<ContractAddress>;
    
    // Admin functions
    fn transfer_admin(ref self: TContractState, new_admin: ContractAddress);
    fn claim_admin_ownership(ref self: TContractState);
    fn get_admin(self: @TContractState) -> ContractAddress;
    fn get_new_admin(self: @TContractState) -> ContractAddress;
    fn toggle_event_suspended_status(ref self: TContractState, event_identifier: u256, status: bool);
    
    // Sponsorship functions
    fn sponsor_event(ref self: TContractState, event_identifier: u256, amt: u256, uri: ByteArray);
    fn withdraw_sponsorship_funds(ref self: TContractState, amt: u256);
    fn set_sponsorship_contract(ref self: TContractState, sponsor_contract_address: ContractAddress);
    fn get_event_sponsorship_balance(self: @TContractState, event: ContractAddress) -> u256;
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
        syscalls::deploy_syscall, contract_address_const,
    };
    use core::starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Vec,
        MutableVecTrait, VecTrait,
    };
    use attendsys::contracts::AttenSysSponsor::{
        IAttenSysSponsorDispatcher, IAttenSysSponsorDispatcherTrait,
    };
    use attendsys::contracts::modules::common::{EventStruct as ModuleEventStruct, Time as ModuleTime};
    use attendsys::contracts::modules::event_management::event_manager;

    #[storage]
    struct Storage {
        // Event storage
        all_event: Vec<EventStruct>,
        specific_event_with_identifier: Map::<u256, EventStruct>,
        event_identifier: u256,
        event_nft_contract_address: Map::<u256, ContractAddress>,
        event_exists: Map::<ContractAddress, bool>,
        events_created_by_address: Map::<ContractAddress, Vec<EventStruct>>,
        
        // Attendance tracking
        attendees_registered_for_event_with_identifier: Map::<u256, Vec<AttendeeInfo>>,
        attendance_status: Map::<(ContractAddress, u256), bool>,
        all_registered_event_by_user: Map::<ContractAddress, Vec<UserAttendedEventStruct>>,
        all_attended_event: Map::<ContractAddress, Vec<UserAttendedEventStruct>>,
        registered: Map::<(ContractAddress, u256), bool>,
        all_attendance_marked_for_event: Map::<u256, Vec<ContractAddress>>,
        
        // NFT and system configuration
        hash: ClassHash,
        admin: ContractAddress,
        intended_new_admin: ContractAddress,
        track_minted_nft_id: Map::<(u256, ContractAddress), u256>,
        
        // Sponsorship
        event_to_balance_of_sponsorship: Map::<ContractAddress, u256>,
        event_to_list_of_sponsors: Map::<ContractAddress, Vec<ContractAddress>>,
        token_address: ContractAddress,
        sponsorship_contract_address: ContractAddress,
    }

    #[derive(Drop, Clone, Serde, starknet::Store)]
    pub struct EventStruct {
        pub event_name: ByteArray,
        pub time: Time,
        pub active_status: bool,
        pub signature_count: u256,
        pub event_organizer: ContractAddress,
        pub registered_attendants: u256,
        pub event_uri: ByteArray,
        pub is_suspended: bool,
        pub event_id : u256,
        pub location : u8, // 0 represents online, 1 represents physical
        pub canceled : bool
    }

    #[derive(Drop, Copy, Serde, starknet::Store)]
    pub struct Time {
        pub registration_open: u8, //0 means false, 1 means true
        pub start_time: u256,
        pub end_time: u256,
    }

    #[derive(Drop, Clone, Serde, starknet::Store)]
    pub struct AttendeeInfo {
        pub attendee_address: ContractAddress,
        pub attendee_uri: ByteArray,
    }

    #[derive(Drop, Clone, Serde, starknet::Store)]
    pub struct UserAttendedEventStruct {
        pub event_name: ByteArray,
        pub time: Time,
        pub event_organizer: ContractAddress,
        pub event_id : u256,
        pub event_uri: ByteArray,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Sponsor: Sponsor,
        Withdrawn: Withdrawn,
        EventCreated: EventCreated,
        EventEnded: EventEnded,
        AttendanceMarked: AttendanceMarked,
        RegisteredForEvent: RegisteredForEvent,
        RegistrationStatusChanged: RegistrationStatusChanged,
        AdminTransferred: AdminTransferred,
        AdminOwnershipClaimed: AdminOwnershipClaimed,
        BatchCertificationCompleted: BatchCertificationCompleted,
    }

    // Event definitions
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

    #[derive(Drop, starknet::Event)]
    pub struct EventCreated {
        pub event_identifier: u256,
        pub event_name: ByteArray,
        pub event_organizer: ContractAddress,
        pub event_uri: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    pub struct EventEnded {
        pub event_identifier: u256,
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
        pub registration_open: u8,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AdminTransferred {
        pub old_admin: ContractAddress,
        pub new_admin: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AdminOwnershipClaimed {
        pub new_admin: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BatchCertificationCompleted {
        pub event_identifier: u256,
        pub certified_attendees: Array<ContractAddress>,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        _hash: ClassHash,
        _token_address: ContractAddress,
        sponsorship_contract_address: ContractAddress,
    ) {
        self.admin.write(owner);
        self.hash.write(_hash);
        self.token_address.write(_token_address);
        self.sponsorship_contract_address.write(sponsorship_contract_address);
    }

    #[abi(embed_v0)]
    impl IAttenSysEventImpl of super::IAttenSysEvent<ContractState> {
        // CORE EVENT MANAGEMENT FUNCTIONS
        fn create_event(
            ref self: ContractState,
            owner_: ContractAddress,
            event_name: ByteArray,
            base_uri: ByteArray,
            name_: ByteArray,
            symbol: ByteArray,
            start_time_: u256,
            end_time_: u256,
            reg_status: u8,
            event_uri: ByteArray,
            event_location : u8,
        ) -> ContractAddress {
            let pre_existing_counter = self.event_identifier.read();
            let new_identifier = pre_existing_counter + 1;
            
            // Use the module to create event
            let (deployed_contract_address, module_event) = event_manager::create_event(
                owner_,
                event_name.clone(),
                base_uri,
                name_,
                symbol,
                start_time_,
                end_time_,
                reg_status,
                event_uri.clone(),
                event_location,
                self.hash.read(),
                new_identifier,
            );
            
            // Convert to local EventStruct
            let event_struct = EventStruct {
                event_name: event_name.clone(),
                time: Time {
                    registration_open: module_event.time.registration_open,
                    start_time: module_event.time.start_time,
                    end_time: module_event.time.end_time,
                },
                active_status: true,
                signature_count: 0,
                event_organizer: owner_,
                registered_attendants: 0,
                event_uri: event_uri.clone(),
                is_suspended: false,
                event_id: new_identifier,
                location: event_location,
                canceled: false,
            };

            // Store event data
            self.event_nft_contract_address.entry(new_identifier).write(deployed_contract_address);
            self.all_event.append().write(event_struct.clone());
            self.specific_event_with_identifier.entry(new_identifier).write(event_struct.clone());
            self.events_created_by_address.entry(get_caller_address()).append().write(event_struct);
            self.event_identifier.write(new_identifier);
            self.track_minted_nft_id.entry((new_identifier, deployed_contract_address)).write(1);
            self.event_exists.entry(owner_).write(true);
            
            // Emit event creation
            self.emit(
                Event::EventCreated(
                    EventCreated {
                        event_identifier: new_identifier,
                        event_name: event_name,
                        event_organizer: owner_,
                        event_uri: event_uri,
                    },
                ),
            );

            deployed_contract_address
        }

        fn end_event(ref self: ContractState, event_identifier: u256) {
            assert(
                self.get_event_suspended_status(event_identifier) == false, 'event is suspended'
            );
            self.end_event_(event_identifier);
            self.emit(Event::EventEnded(EventEnded { event_identifier: event_identifier }));
        }

        fn start_end_reg(ref self: ContractState, reg_stat: u8, event_identifier: u256) {
            let event_details = self.specific_event_with_identifier.entry(event_identifier).read();
            assert(event_details.is_suspended == false, 'event is suspended');
            //only event owner
            assert(event_details.event_organizer == get_caller_address(), 'not authorized');
            
            // Use module to validate registration status
            event_manager::validate_reg_status(reg_stat);
            
            self.specific_event_with_identifier.entry(event_identifier).time.registration_open.write(reg_stat);
            
            //loop through the all_event vec and end the specific event
            if self.all_event.len() > 0 {
                for i in 0..self.all_event.len() {
                    if self.all_event.at(i).read().event_name == event_details.event_name {
                        self.all_event.at(i).time.registration_open.write(reg_stat);
                    }
                };
            }
            
            self.emit(
                Event::RegistrationStatusChanged(
                    RegistrationStatusChanged {
                        event_identifier: event_identifier, 
                        registration_open: reg_stat,
                    },
                ),
            );
        }

        fn cancel_event(ref self: ContractState, event_identifier: u256) {
            let event_details = self.specific_event_with_identifier.entry(event_identifier).read(); 
            let caller = get_caller_address();
            assert(caller == event_details.event_organizer, 'not authorized');
            
            if self.all_event.len() > 0 {
                for i in 0..self.all_event.len() {
                    if self.all_event.at(i).read().event_name == event_details.event_name {
                        self.all_event.at(i).canceled.write(true);
                    }
                };
            }
            
            self.specific_event_with_identifier.entry(event_identifier).canceled.write(true);
        }

        // EVENT QUERY FUNCTIONS
        fn get_event_details(self: @ContractState, event_identifier: u256) -> EventStruct {
            self.specific_event_with_identifier.entry(event_identifier).read()
        }

        fn get_all_events(self: @ContractState) -> Array<EventStruct> {
            let mut arr = array![];
            for i in 0..self.all_event.len() {
                arr.append(self.all_event.at(i).read());
            };
            arr
        }

        fn get_all_created_events(self: @ContractState, organizer: ContractAddress) -> Array<EventStruct> {
            let mut arr = array![];
            let vec = self.events_created_by_address.entry(organizer);
            
            for i in 0..vec.len() {
                if let Option::Some(element) = vec.get(i) {
                    arr.append(element.read());
                }
            };
            
            arr
        }

        fn get_event_nft_contract(self: @ContractState, event_identifier: u256) -> ContractAddress {
            self.event_nft_contract_address.entry(event_identifier).read()
        }

        fn get_cancelation_status(self: @ContractState, event_identifier: u256) -> bool {
            self.specific_event_with_identifier.entry(event_identifier).read().canceled
        }

        fn get_if_registration_is_open(self: @ContractState, event_identifier: u256) -> u8 {
            self.specific_event_with_identifier.entry(event_identifier).read().time.registration_open
        }

        fn get_event_suspended_status(self: @ContractState, event_identifier: u256) -> bool {
            self.specific_event_with_identifier.entry(event_identifier).read().is_suspended
        }

        // ATTENDANCE FUNCTIONS
        fn batch_certify_attendees(ref self: ContractState, event_identifier: u256) {
            //only event owner
            let event_details = self.specific_event_with_identifier.entry(event_identifier).read();
            assert(event_details.event_organizer == get_caller_address(), 'not authorized');
            assert(event_details.is_suspended == false, 'event is suspended');
            
            //update attendance_status here
            if self.all_attendance_marked_for_event.entry(event_identifier).len() > 0 {
                let nft_contract_address = self.event_nft_contract_address.entry(event_identifier).read();
                let mut certified_attendees = array![];
                
                for i in 0..self.all_attendance_marked_for_event.entry(event_identifier).len() {
                    let attendee = self.all_attendance_marked_for_event.entry(event_identifier).at(i).read();
                    self.attendance_status.entry((attendee, event_identifier)).write(true);
                    
                    let nft_id = self.track_minted_nft_id.entry((event_identifier, nft_contract_address)).read();
                    let nft_dispatcher = super::IAttenSysNftDispatcher { contract_address: nft_contract_address };
                    nft_dispatcher.mint(attendee, nft_id);
                    
                    self.track_minted_nft_id.entry((event_identifier, nft_contract_address)).write(nft_id + 1);
                    certified_attendees.append(attendee);
                };
                
                self.emit(
                    Event::BatchCertificationCompleted(
                        BatchCertificationCompleted {
                            event_identifier: event_identifier,
                            certified_attendees: certified_attendees,
                        },
                    ),
                );
            }
        }

        fn mark_attendance(ref self: ContractState, event_identifier: u256, attendee_: ContractAddress) {
            let event_details = self.specific_event_with_identifier.entry(event_identifier).read();
            let event_location = event_details.location;
            let caller = get_caller_address();
            let event_organizer_address = event_details.event_organizer;
            
            // Validate conditions
            assert(self.attendance_status.entry((attendee_, event_identifier)).read() == false, 'already marked');
            
            if event_location == 0 {
                assert(caller == attendee_, 'wrong caller');
            } else {
                assert(caller == event_organizer_address, 'wrong caller');
            }
            
            assert(event_details.is_suspended == false, 'event is suspended');
            assert(self.registered.entry((attendee_, event_identifier)).read() == true, 'not registered');
            assert(event_details.active_status == true, 'not started');
            assert(self.specific_event_with_identifier.entry(event_identifier).read().canceled == false, 'event canceled');
            assert(get_block_timestamp().into() >= event_details.time.start_time, 'not started');
            
            // Update attendance data
            let count = self.specific_event_with_identifier.entry(event_identifier).signature_count.read();
            self.specific_event_with_identifier.entry(event_identifier).signature_count.write(count + 1);
            self.attendance_status.entry((attendee_, event_identifier)).write(true);

            // Update all events records
            if self.all_event.len() > 0 {
                for i in 0..self.all_event.len() {
                    if self.all_event.at(i).read().event_name == event_details.event_name {
                        self.all_event.at(i).signature_count.write(count + 1);
                    }
                };
            }
            
            // Add to attendance records
            self.all_attendance_marked_for_event.entry(event_identifier).append().write(attendee_);
            
            let call_data = UserAttendedEventStruct {
                event_name: event_details.event_name, 
                time: event_details.time, 
                event_organizer: event_details.event_organizer, 
                event_id: event_details.event_id, 
                event_uri: event_details.event_uri   
            };
            
            self.all_attended_event.entry(get_caller_address()).append().write(call_data);
            
            // Emit event
            self.emit(
                Event::AttendanceMarked(
                    AttendanceMarked {
                        event_identifier: event_identifier, 
                        attendee: attendee_,
                    },
                ),
            );
        }

        fn register_for_event(ref self: ContractState, event_identifier: u256, user_uri: ByteArray) {
            let event_details = self.specific_event_with_identifier.entry(event_identifier).read();
            
            // Validate conditions
            assert(event_details.is_suspended == false, 'event is suspended');
            assert(self.specific_event_with_identifier.entry(event_identifier).read().canceled == false, 'event canceled');
            assert(self.registered.entry((get_caller_address(), event_identifier)).read() == false, 'already registered');
            
            // Register the user
            self.registered.entry((get_caller_address(), event_identifier)).write(true);
            
            // Update registration count
            let count = self.specific_event_with_identifier.entry(event_identifier).registered_attendants.read();
            self.specific_event_with_identifier.entry(event_identifier).registered_attendants.write(count + 1);

            // Update all events
            if self.all_event.len() > 0 {
                for i in 0..self.all_event.len() {
                    if self.all_event.at(i).read().event_name == event_details.event_name {
                        self.all_event.at(i).registered_attendants.write(count + 1);
                    }
                };
            }
            
            // Add to user's registered events
            let call_data = UserAttendedEventStruct {
                event_name: event_details.event_name, 
                time: event_details.time, 
                event_organizer: event_details.event_organizer, 
                event_id: event_details.event_id, 
                event_uri: event_details.event_uri
            };
            
            self.all_registered_event_by_user.entry(get_caller_address()).append().write(call_data);
            
            // Add attendee info
            let attendee_calldata = AttendeeInfo {
                attendee_address: get_caller_address(), 
                attendee_uri: user_uri
            };
            
            self.attendees_registered_for_event_with_identifier.entry(event_identifier).append().write(attendee_calldata);
            
            // Emit event
            self.emit(
                Event::RegisteredForEvent(
                    RegisteredForEvent {
                        event_identifier: event_identifier, 
                        attendee: get_caller_address(),
                    },
                ),
            );
        }

        fn get_registered_users(self: @ContractState, event_identifier: u256) -> Array<AttendeeInfo> {
            let mut arr = array![];
            let vec = self.attendees_registered_for_event_with_identifier.entry(event_identifier);
            
            for i in 0..vec.len() {
                if let Option::Some(element) = vec.get(i) {
                    arr.append(element.read());
                }
            };
            
            arr
        }

        fn get_attendance_status(self: @ContractState, attendee: ContractAddress, event_identifier: u256) -> bool {
            self.attendance_status.entry((attendee, event_identifier)).read()
        }

        fn get_all_attended_events(self: @ContractState, user: ContractAddress) -> Array<UserAttendedEventStruct> {
            let vec = self.all_attended_event.entry(user);
            let mut arr = array![];
            
            for i in 0..vec.len() {
                if let Option::Some(element) = vec.get(i) {
                    arr.append(element.read());
                }
            };
            
            arr
        }

        fn get_all_list_registered_events(self: @ContractState, user: ContractAddress) -> Array<UserAttendedEventStruct> {
            let mut arr = array![];
            let vec = self.all_registered_event_by_user.entry(user);
            
            for i in 0..vec.len() {
                if let Option::Some(element) = vec.get(i) {
                    arr.append(element.read());
                }
            };
            
            arr
        }

        fn get_all_attendace_marked(self: @ContractState, event_identifier: u256) -> Array<ContractAddress> {
            let mut arr = array![];
            
            for i in 0..self.all_attendance_marked_for_event.entry(event_identifier).len() {
                arr.append(self.all_attendance_marked_for_event.entry(event_identifier).at(i).read());
            };
            
            arr
        }

        // ADMIN FUNCTIONS
        fn transfer_admin(ref self: ContractState, new_admin: ContractAddress) {
            assert(new_admin != self.zero_address(), 'zero address not allowed');
            assert(get_caller_address() == self.admin.read(), 'unauthorized caller');

            let old_admin = self.admin.read();
            self.intended_new_admin.write(new_admin);
            
            self.emit(
                Event::AdminTransferred(
                    AdminTransferred { 
                        old_admin: old_admin, 
                        new_admin: new_admin 
                    },
                ),
            );
        }

        fn claim_admin_ownership(ref self: ContractState) {
            assert(get_caller_address() == self.intended_new_admin.read(), 'unauthorized caller');
            let new_admin = self.intended_new_admin.read();
            
            self.admin.write(self.intended_new_admin.read());
            self.intended_new_admin.write(self.zero_address());
            
            self.emit(Event::AdminOwnershipClaimed(AdminOwnershipClaimed { new_admin: new_admin }));
        }

        fn get_admin(self: @ContractState) -> ContractAddress {
            self.admin.read()
        }

        fn get_new_admin(self: @ContractState) -> ContractAddress {
            self.intended_new_admin.read()
        }

        fn toggle_event_suspended_status(ref self: ContractState, event_identifier: u256, status: bool) {
            self.only_admin();
            self.specific_event_with_identifier.entry(event_identifier).is_suspended.write(status);
        }

        // SPONSORSHIP FUNCTIONS
        fn sponsor_event(ref self: ContractState, event_identifier: u256, amt: u256, uri: ByteArray) {
            assert(event_identifier > 0, 'Invalid event ID');
            assert(uri.len() > 0, 'uri is empty');
            
            // Check if event exists
            let event = self.specific_event_with_identifier.entry(event_identifier).read().event_organizer;
            assert(self.event_exists.entry(event).read(), 'No such event');
            assert(amt > 0, 'Invalid amount');
            
            let sponsor = get_caller_address();
            let balance = self.event_to_balance_of_sponsorship.entry(event).read();
            let sponsor_contract_address = self.sponsorship_contract_address.read();
            let token_address = self.token_address.read();
            
            // Call sponsor contract
            let sponsor_dispatcher = IAttenSysSponsorDispatcher {
                contract_address: sponsor_contract_address,
            };
            
            sponsor_dispatcher.deposit(sponsor, token_address, amt);
            self.event_to_balance_of_sponsorship.entry(event).write(balance + amt);

            // Track sponsors
            let mut existing_sponsors = self.event_to_list_of_sponsors.entry(event);
            let mut sponsor_exists = false;
            
            for i in 0..existing_sponsors.len() {
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
            assert(amt > 0, 'Invalid withdrawal amount');
            let event = get_caller_address();
            assert(self.event_exists.entry(event).read(), 'No such event');
            
            let event_sponsorship_balance = self.event_to_balance_of_sponsorship.entry(event).read();
            assert(event_sponsorship_balance > 0, 'Zero funds retrieved');
            assert(event_sponsorship_balance >= amt, 'Insufficient funds');
            
            let token_address = self.token_address.read();
            let sponsor_contract_address = self.sponsorship_contract_address.read();
            
            let sponsor_dispatcher = IAttenSysSponsorDispatcher {
                contract_address: sponsor_contract_address,
            };
            
            sponsor_dispatcher.withdraw(token_address, amt);
            self.event_to_balance_of_sponsorship.entry(event).write(event_sponsorship_balance - amt);
            
            self.emit(Withdrawn { amt, event });
        }

        fn set_sponsorship_contract(ref self: ContractState, sponsor_contract_address: ContractAddress) {
            self.only_admin();
            assert(!sponsor_contract_address.is_zero(), 'Null address not allowed');
            self.sponsorship_contract_address.write(sponsor_contract_address);
        }

        fn get_event_sponsorship_balance(self: @ContractState, event: ContractAddress) -> u256 {
            self.event_to_balance_of_sponsorship.entry(event).read()
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn end_event_(ref self: ContractState, event_identifier: u256) {
            let event_details = self.specific_event_with_identifier.entry(event_identifier).read();
            //only event owner
            assert(event_details.event_organizer == get_caller_address(), 'not authorized');

            let time_data: Time = Time {
                registration_open: 0, 
                start_time: event_details.time.start_time, 
                end_time: 0,
            };
            
            //reset specific event with identifier
            self.specific_event_with_identifier.entry(event_identifier).time.write(time_data);
            self.specific_event_with_identifier.entry(event_identifier).active_status.write(false);
            
            //loop through the all_event vec and end the specific event
            if self.all_event.len() > 0 {
                for i in 0..self.all_event.len() {
                    if self.all_event.at(i).read().event_name == event_details.event_name {
                        self.all_event.at(i).time.write(time_data);
                        self.all_event.at(i).active_status.write(false);
                    }
                };
            }
        }

        fn zero_address(self: @ContractState) -> ContractAddress {
            contract_address_const::<0>()
        }

        fn only_admin(self: @ContractState) {
            assert(get_caller_address() == self.admin.read(), 'unauthorized caller');
        }
    }
}
