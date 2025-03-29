// use core::starknet::{ContractAddress, ClassHash};
// use core::starknet::storage::{Map, Vec};
// use crate::base::types::{Organization, Bootcamp, Instructor, Class, Student, RegisteredBootcamp};

// // Organization-related storage
// #[starknet::component]
// pub trait OrganizationStorage<TContractState> {
//     // Organization profile storage
//     fn get_organization_info(self: @TContractState, address: ContractAddress) -> Organization;
//     fn set_organization_info(ref self: TContractState, address: ContractAddress, org: Organization);
    
//     // All organizations
//     fn get_all_org_info(self: @TContractState) -> Array<Organization>;
//     fn add_org_info(ref self: TContractState, org: Organization);
    
//     // Organization creation status
//     fn get_created_status(self: @TContractState, address: ContractAddress) -> bool;
//     fn set_created_status(ref self: TContractState, address: ContractAddress, status: bool);
    
//     // Organization suspension status
//     fn is_org_suspended(self: @TContractState, address: ContractAddress) -> bool;
//     fn set_org_suspended(ref self: TContractState, address: ContractAddress, status: bool);
// }

// // Instructor-related storage
// #[starknet::component]
// pub trait InstructorStorage<TContractState> {
//     // Organization instructors
//     fn get_org_instructors(self: @TContractState, org: ContractAddress) -> Array<Instructor>;
//     fn add_org_instructor(ref self: TContractState, org: ContractAddress, instructor: Instructor);
    
//     // Instructor association to org
//     fn is_instructor_part_of_org(self: @TContractState, org: ContractAddress, instructor: ContractAddress) -> bool;
//     fn set_instructor_part_of_org(ref self: TContractState, org: ContractAddress, instructor: ContractAddress, status: bool);
    
//     // Instructor information
//     fn get_instructor_info(self: @TContractState, instructor: ContractAddress) -> Array<Instructor>;
//     fn add_instructor_info(ref self: TContractState, instructor: ContractAddress, info: Instructor);
// }

// // Bootcamp-related storage
// #[starknet::component]
// pub trait BootcampStorage<TContractState> {
//     // All bootcamps
//     fn get_all_bootcamps_created(self: @TContractState) -> Array<Bootcamp>;
//     fn add_bootcamp(ref self: TContractState, bootcamp: Bootcamp);
    
//     // Organization bootcamps
//     fn get_org_bootcamps(self: @TContractState, org: ContractAddress) -> Array<Bootcamp>;
//     fn add_org_bootcamp(ref self: TContractState, org: ContractAddress, bootcamp: Bootcamp);
    
//     // Bootcamp suspension status
//     fn is_bootcamp_suspended(self: @TContractState, org: ContractAddress, bootcamp_id: u64) -> bool;
//     fn set_bootcamp_suspended(ref self: TContractState, org: ContractAddress, bootcamp_id: u64, status: bool);
    
//     // Bootcamp classes
//     fn get_bootcamp_class_data_id(self: @TContractState, org: ContractAddress, bootcamp_id: u64) -> Array<u64>;
//     fn add_bootcamp_class_id(ref self: TContractState, org: ContractAddress, bootcamp_id: u64, class_id: u64);
// }

// // Media-related storage
// #[starknet::component]
// pub trait MediaStorage<TContractState> {
//     // Uploaded videos links
//     fn get_uploaded_videos_link(self: @TContractState, org: ContractAddress, bootcamp_id: u64) -> Array<ByteArray>;
//     fn add_uploaded_video_link(ref self: TContractState, org: ContractAddress, bootcamp_id: u64, link: ByteArray);
// }

// // Student-related storage
// #[starknet::component]
// pub trait StudentStorage<TContractState> {
//     // Student classes
//     fn get_student_classes(self: @TContractState, student: ContractAddress) -> Array<Class>;
//     fn add_student_class(ref self: TContractState, student: ContractAddress, class: Class);
    
//     // Student info
//     fn get_student_info(self: @TContractState, student: ContractAddress) -> Student;
//     fn set_student_info(ref self: TContractState, student: ContractAddress, info: Student);
    
//     // Student bootcamps
//     fn get_student_bootcamps(self: @TContractState, student: ContractAddress) -> Array<RegisteredBootcamp>;
//     fn add_student_bootcamp(ref self: TContractState, student: ContractAddress, bootcamp: RegisteredBootcamp);
    
//     // Student specific bootcamps for an org
//     fn get_student_specific_bootcamp(self: @TContractState, student: ContractAddress, org: ContractAddress) -> Array<RegisteredBootcamp>;
//     fn add_student_specific_bootcamp(ref self: TContractState, student: ContractAddress, org: ContractAddress, bootcamp: RegisteredBootcamp);
// }

// // Attendance-related storage
// #[starknet::component]
// pub trait AttendanceStorage<TContractState> {
//     // Student attendance status
//     fn get_student_attendance_status(self: @TContractState, org: ContractAddress, bootcamp_id: u64, class_id: u64, student: ContractAddress) -> bool;
//     fn set_student_attendance_status(ref self: TContractState, org: ContractAddress, bootcamp_id: u64, class_id: u64, student: ContractAddress, status: bool);
    
//     // Instructor-student status
//     fn get_inst_student_status(self: @TContractState, instructor: ContractAddress, student: ContractAddress) -> bool;
//     fn set_inst_student_status(ref self: TContractState, instructor: ContractAddress, student: ContractAddress, status: bool);
    
//     // Certified students
//     fn is_student_certified(self: @TContractState, org: ContractAddress, bootcamp_id: u64, student: ContractAddress) -> bool;
//     fn set_student_certified(ref self: TContractState, org: ContractAddress, bootcamp_id: u64, student: ContractAddress, status: bool);
    
//     // All certified students for a bootcamp
//     fn get_certified_students_for_bootcamp(self: @TContractState, org: ContractAddress, bootcamp_id: u64) -> Array<ContractAddress>;
//     fn add_certified_student_for_bootcamp(ref self: TContractState, org: ContractAddress, bootcamp_id: u64, student: ContractAddress);
// }

// // Registration-related storage
// #[starknet::component]
// pub trait RegistrationStorage<TContractState> {
//     // Organization registration requests
//     fn get_org_requests(self: @TContractState, org: ContractAddress) -> Array<Student>;
//     fn add_org_request(ref self: TContractState, org: ContractAddress, student: Student);
// }

// // Sponsorship-related storage
// #[starknet::component]
// pub trait SponsorshipStorage<TContractState> {
//     // Organization sponsorship balance
//     fn get_org_sponsorship_balance(self: @TContractState, org: ContractAddress) -> u256;
//     fn set_org_sponsorship_balance(ref self: TContractState, org: ContractAddress, amount: u256);
    
//     // Sponsorship contract address
//     fn get_sponsorship_contract_address(self: @TContractState) -> ContractAddress;
//     fn set_sponsorship_contract_address(ref self: TContractState, address: ContractAddress);
// }

// // Admin-related storage
// #[starknet::component]
// pub trait AdminStorage<TContractState> {
//     // Admin address
//     fn get_admin(self: @TContractState) -> ContractAddress;
//     fn set_admin(ref self: TContractState, admin: ContractAddress);
    
//     // Intended new admin
//     fn get_intended_new_admin(self: @TContractState) -> ContractAddress;
//     fn set_intended_new_admin(ref self: TContractState, admin: ContractAddress);
// }

// // System-related storage
// #[starknet::component]
// pub trait SystemStorage<TContractState> {
//     // NFT class hash
//     fn get_nft_class_hash(self: @TContractState) -> ClassHash;
//     fn set_nft_class_hash(ref self: TContractState, hash: ClassHash);
    
//     // Token address
//     fn get_token_address(self: @TContractState) -> ContractAddress;
//     fn set_token_address(ref self: TContractState, address: ContractAddress);
// }




use core::starknet::{ContractAddress, ClassHash};
use core::starknet::storage::{Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait, MutableVecTrait};
use crate::base::types::{Organization, Bootcamp, Instructor, Class, Student, RegisteredBootcamp, Bootcampclass};

#[storage]
struct OrganizationStorage {
    created_status: Map<ContractAddress, bool>,
    organization_info: Map<ContractAddress, Organization>,
    all_org_info: Vec<Organization>,
    org_suspended: Map<ContractAddress, bool>,
}

#[storage]
struct InstructorStorage {
    instructor_part_of_org: Map<(ContractAddress, ContractAddress), bool>,
    org_to_instructors: Map<ContractAddress, Vec<Instructor>>,
}

#[storage]
struct BootcampStorage {
    org_to_bootcamps: Map<ContractAddress, Vec<Bootcamp>>,
    all_bootcamps: Vec<Bootcamp>,
    bootcamp_suspended: Map<ContractAddress, Map<u64, bool>>,
    bootcamp_class_data_id: Map<(ContractAddress, u64), Vec<u64>>,
}

#[storage]
struct MediaStorage {
    org_to_uploaded_videos_link: Map<(ContractAddress, u64), Vec<ByteArray>>,
}

#[storage]
struct StudentStorage {
    student_info: Map<ContractAddress, Student>,
    student_to_classes: Map<ContractAddress, Vec<Class>>,
    certify_student: Map<(ContractAddress, u64, ContractAddress), bool>,
    certified_students_for_bootcamp: Map<(ContractAddress, u64), Vec<ContractAddress>>,
}

#[storage]
struct AttendanceStorage {
    student_attendance_status: Map<(ContractAddress, u64, u64, ContractAddress), bool>,
}

#[storage]
struct RegistrationStorage {
    org_to_requests: Map<ContractAddress, Vec<Student>>,
    student_to_registered_bootcamp: Map<ContractAddress, Vec<RegisteredBootcamp>>,
}

#[storage]
struct SponsorshipStorage {
    sponsorship_contract_address: ContractAddress,
    org_sponsorship_balance: Map<ContractAddress, u256>,
}

#[storage]
struct AdminStorage {
    admin: ContractAddress,
    new_admin: ContractAddress,
}

#[storage]
struct SystemStorage {
    hash: ClassHash,
    token_address: ContractAddress,
}