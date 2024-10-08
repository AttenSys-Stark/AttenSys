use core::starknet::ContractAddress;

#[starknet::interface]
pub trait IAttenSysEvent<TContractState> {
    //implement a paid event feature in the create_event & implement a register for event function that takes into consideration payment factor
    fn create_event(ref self: TContractState, owner_: ContractAddress, event_name: ByteArray, start_time_: u256, end_time_: u256);
    fn alter_start_end_time(ref self: TContractState, new_start_time: u256, new_end_time : u256);
    fn batch_certify_attendees(ref self: TContractState, attendees: Array<ContractAddress>);
    fn mark_attendance(ref self: TContractState, event_identifier: u256);
    fn register_for_event(ref self: TContractState, event_identifier: u256);
    // fn get_registered_users(ref self: TContractState, event_identifier : u256, passcode : felt252) -> Array<ContractAddress>;
    fn get_attendance_status(ref self: TContractState, attendee: ContractAddress, event_identifier : u256) -> bool;
    fn get_all_attended_events(ref self: TContractState, user: ContractAddress)-> Array<AttenSysEvent::UserAttendedEventStruct>;
    fn get_all_list_registered_events(ref self: TContractState, user : ContractAddress) -> Array<AttenSysEvent::UserAttendedEventStruct>;
    
    //function to create an event, ability to start and end event in the event struct, each event will have a unique ID
    //function to mark attendace, with signature. keep track of all addresses that have signed (implementing a gasless transaction from frontend);
    //function to batch issue attendance certificate for events
    //function to transfer event ownership
    //implement a feature to work on the passcode, save it when creating the event
}

#[starknet::contract]
mod AttenSysEvent {
    use core::starknet::{ContractAddress, get_caller_address,get_block_timestamp};
    use core::starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait, MutableVecTrait
    };

    #[storage]
    struct Storage {
        //saves all event
        all_event : Vec<EventStruct>,
        //saves specific event
        specific_event_with_identifier : Map::<u256, EventStruct>,
        //saves attendees details that reg for a particular event, use an admin passcode that can be hashed to protect this information
        attendees_registered_for_event_with_identifier : Map::<(u256, felt252), Vec<ContractAddress>>,
        //event identifier
        event_identifier : u256,
        //saves attendance status
        attendance_status : Map::<(ContractAddress, u256), bool>,
        //saves user registered event
        all_registered_event_by_user : Map::<ContractAddress, Vec<UserAttendedEventStruct>>,
        //saves all attended events
        all_attended_event : Map::<ContractAddress, Vec<UserAttendedEventStruct>>,
        //saves registraction status
        registered : Map::<(ContractAddress, u256), bool>,
        //save the actual addresses that marked attendance
        all_attendance_marked_for_event : Map::<u256, Vec<ContractAddress>>,

    }

    //create a separate struct for the all_attended_event that will only have the time the event took place and its name
    #[derive(Drop, Serde, starknet::Store)]
    pub struct EventStruct {
        event_name : ByteArray,
        time : Time,
        active_status : bool,
        signature_count : u256,
        event_organizer : ContractAddress,
        registered_attendants : u256,
    }

    #[derive(Drop,Copy,Serde, starknet::Store)]
    pub struct Time {
        start_time : u256,
        end_time : u256,
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct UserAttendedEventStruct {
        event_name : ByteArray,
        time : u256,
    }


    #[abi(embed_v0)]
    impl IAttenSysEventImpl of super::IAttenSysEvent<ContractState> {
        fn create_event(ref self: ContractState, owner_: ContractAddress, event_name: ByteArray, start_time_: u256, end_time_: u256){
            let pre_existing_counter = self.event_identifier.read();
            let new_identifier = pre_existing_counter + 1;
            
            let time_data : Time = Time {
                start_time : start_time_,
                end_time : end_time_,
            };
            let event_call_data : EventStruct = EventStruct {
                event_name : event_name.clone(),
                time : time_data,
                active_status : true,
                signature_count : 0,
                event_organizer : owner_,
                registered_attendants : 0,
            };

            self.all_event.append().write(event_call_data);
            self.specific_event_with_identifier.entry(new_identifier).write(EventStruct{
                event_name : event_name,
                time : time_data,
                active_status : true,
                signature_count : 0,
                event_organizer : owner_,
                registered_attendants : 0,
            }
            );
            self.event_identifier.write(new_identifier);
        }

        fn alter_start_end_time(ref self: ContractState, new_start_time: u256, new_end_time : u256){
            //only event owner

        }

        fn batch_certify_attendees(ref self: ContractState, attendees: Array<ContractAddress>){
            //only event owner
            //update attendance_status here

        }

        fn mark_attendance(ref self: ContractState, event_identifier: u256){
            let event_details = self.specific_event_with_identifier.entry(event_identifier).read();
            assert(self.registered.entry((get_caller_address(), event_identifier)).read() == true, 'already registered');
            assert(event_details.active_status == true, 'not started');
            assert(get_block_timestamp().into() >= event_details.time.start_time, 'not started');       
            let count = self.specific_event_with_identifier.entry(event_identifier).signature_count.read();            
            self.specific_event_with_identifier.entry(event_identifier).signature_count.write(count +1);

            if self.all_event.len() > 0 {
                for i in 0..self.all_event.len() {
                    if self.all_event.at(i).read().event_name == event_details.event_name {
                        self.all_event.at(i).signature_count.write(count +1);
                    }
                }
            }
            self.all_attendance_marked_for_event.entry(event_identifier).append().write(get_caller_address());
            let call_data = UserAttendedEventStruct {
                event_name : event_details.event_name,
                time : event_details.time.start_time,
            };
            self.all_attended_event.entry(get_caller_address()).append().write(call_data);
        }

        fn register_for_event(ref self: ContractState, event_identifier: u256){
            let event_details = self.specific_event_with_identifier.entry(event_identifier).read();
            //can only register once
            assert(self.registered.entry((get_caller_address(), event_identifier)).read() == false, 'already registered');
            assert(get_block_timestamp().into() >= event_details.time.start_time, 'not started');
            self.registered.entry((get_caller_address(),event_identifier)).write(true);

            let count = self.specific_event_with_identifier.entry(event_identifier).registered_attendants.read();
            self.specific_event_with_identifier.entry(event_identifier).registered_attendants.write(count +1);
           
            if self.all_event.len() > 0 {
                for i in 0..self.all_event.len() {
                    if self.all_event.at(i).read().event_name == event_details.event_name {
                        self.all_event.at(i).registered_attendants.write(count +1);
                    }
                }
            }
            let call_data = UserAttendedEventStruct {
                event_name : event_details.event_name,
                time : event_details.time.start_time,
            };
            self.all_registered_event_by_user.entry(get_caller_address()).append().write(call_data);
        }

        // fn get_registered_users(ref self: ContractState, event_identifier : u256, passcode : felt252 ) -> Array<ContractAddress>{

        // }

        fn get_attendance_status(ref self: ContractState, attendee: ContractAddress, event_identifier : u256) -> bool {
            self.attendance_status.entry((attendee,event_identifier)).read()
        }

        fn get_all_attended_events(ref self: ContractState, user: ContractAddress)-> Array<UserAttendedEventStruct>{
                let mut arr = array![];
                let vec = self.all_attended_event.entry(user);
                let len = vec.len();
                let mut i: u64 = 0;

                loop {
                    if i >= len {
                        break;
                    }
                    if let Option::Some(element) = vec.get(i){
                        arr.append(element.read());
                    }
                    i +=1;
                };

                arr
        } 

        fn get_all_list_registered_events(ref self: ContractState, user : ContractAddress) -> Array<UserAttendedEventStruct>{    
                let mut arr = array![];
                let vec = self.all_registered_event_by_user.entry(user);
                let len = vec.len();
                let mut i: u64 = 0;

                loop {
                    if i >= len {
                        break;
                    }
                    if let Option::Some(element) = vec.get(i){
                        arr.append(element.read());
                    }
                    i +=1;
                };

                arr
        }

    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn end_event(ref self: ContractState, event_identifier: u256){
            let event_details = self.specific_event_with_identifier.entry(event_identifier).read();
            //only event owner
            assert(event_details.event_organizer == get_caller_address(), 'not authorized');

            let time_data : Time = Time {
                start_time : event_details.time.start_time,
                end_time : 0,
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
                }
            }  
        }
    }
}