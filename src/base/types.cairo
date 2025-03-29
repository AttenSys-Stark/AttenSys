use starknet::ContractAddress;

#[derive(Drop, Clone, Serde, starknet::Store)]
pub struct Course {
    pub owner: ContractAddress,
    pub course_identifier: u256,
    pub accessment: bool,
    pub uri: ByteArray,
    pub course_ipfs_uri: ByteArray,
    pub is_suspended: bool,
}
//   find a way to keep track of all course identifiers for each owner.
#[derive(Drop, Serde, starknet::Store)]
pub struct Creator {
    pub address: ContractAddress,
    pub number_of_courses: u256,
    pub creator_status: bool,
}

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct Uri {
    pub first: felt252,
    pub second: felt252,
}

#[derive(Drop, Serde, starknet::Store)]
    pub struct Organization {
        pub address_of_org: ContractAddress,
        pub org_name: ByteArray,
        pub number_of_instructors: u256,
        pub number_of_students: u256,
        pub number_of_all_classes: u256,
        pub number_of_all_bootcamps: u256,
        pub org_ipfs_uri: ByteArray,
        pub total_sponsorship_fund: u256,
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct Bootcamp {
        pub bootcamp_id: u64,
        pub address_of_org: ContractAddress,
        pub org_name: ByteArray,
        pub bootcamp_name: ByteArray,
        pub number_of_instructors: u256,
        pub number_of_students: u256,
        pub number_of_all_bootcamp_classes: u256,
        pub nft_address: ContractAddress,
        pub bootcamp_ipfs_uri: ByteArray,
        pub active_meet_link: ByteArray,
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct Instructor {
        pub address_of_instructor: ContractAddress,
        pub num_of_classes: u256,
        pub name_of_org: ByteArray,
        pub organization_address: ContractAddress,
    }

    #[derive(Drop, Copy, Serde, starknet::Store)]
    pub struct Class {
        pub address_of_org: ContractAddress,
        pub instructor: ContractAddress,
        pub num_of_reg_students: u32,
        pub active_status: bool,
        pub bootcamp_id: u64,
    }

    #[derive(Drop, Copy, Serde, starknet::Store)]
    pub struct Bootcampclass {
        pub address_of_org: ContractAddress,
        pub bootcamp_id: u64,
        pub attendance: bool,
        pub student_address: ContractAddress,
        pub class_id: u64,
    }


    #[derive(Drop, Copy, Serde, starknet::Store)]
    pub struct RegisteredBootcamp {
        pub address_of_org: ContractAddress,
        pub student: ContractAddress,
        pub acceptance_status: bool,
        pub bootcamp_id: u64,
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct Student {
        pub address_of_student: ContractAddress,
        pub num_of_bootcamps_registered_for: u256,
        pub status: u8,
        pub student_details_uri: ByteArray,
    }