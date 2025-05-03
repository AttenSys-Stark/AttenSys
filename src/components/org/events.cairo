use core::starknet::storage::{Map, Vec};
use core::starknet::{ClassHash, ContractAddress};

#[event]
#[derive(Drop, starknet::Event)]
pub enum Event {
    Sponsor: Sponsor,
    Withdrawn: Withdrawn,
    OrganizationProfile: OrganizationProfile,
    InstructorAddedToOrg: InstructorAddedToOrg,
    InstructorRemovedFromOrg: InstructorRemovedFromOrg,
    BootCampCreated: BootCampCreated,
    ActiveMeetLinkAdded: ActiveMeetLinkAdded,
    VideoLinkUploaded: VideoLinkUploaded,
    BootcampRegistration: BootcampRegistration,
    RegistrationApproved: RegistrationApproved,
    RegistrationDeclined: RegistrationDeclined,
    AttendanceMarked: AttendanceMarked,
    StudentsCertified: StudentsCertified,
    SponsorshipAddressSet: SponsorshipAddressSet,
    OrganizationSponsored: OrganizationSponsored,
    SponsorshipFundWithdrawn: SponsorshipFundWithdrawn,
    OrganizationSuspended: OrganizationSuspended,
    BootCampSuspended: BootCampSuspended,
}

#[derive(Drop, starknet::Event)]
pub struct Sponsor {
    pub amt: u256,
    pub uri: ByteArray,
    #[key]
    pub organization: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct Withdrawn {
    pub amt: u256,
    #[key]
    pub organization: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct OrganizationProfile {
    pub org_name: ByteArray,
    pub org_ipfs_uri: ByteArray,
}

#[derive(Drop, starknet::Event)]
pub struct InstructorAddedToOrg {
    pub org_name: ByteArray,
    pub org_address: ContractAddress,
    #[key]
    pub instructor: Array<ContractAddress>,
}

#[derive(Drop, starknet::Event)]
pub struct InstructorRemovedFromOrg {
    pub instructor_addr: ContractAddress,
    pub org_owner: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct BootCampCreated {
    pub org_name: ByteArray,
    pub org_address: ContractAddress,
    pub bootcamp_name: ByteArray,
    pub nft_name: ByteArray,
    pub nft_symbol: ByteArray,
    pub nft_uri: ByteArray,
    pub num_of_classes: u256,
    pub bootcamp_ipfs_uri: ByteArray,
}

#[derive(Drop, starknet::Event)]
pub struct ActiveMeetLinkAdded {
    pub meet_link: ByteArray,
    pub bootcamp_id: u64,
    pub is_instructor: bool,
    pub org_address: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct VideoLinkUploaded {
    pub video_link: ByteArray,
    pub is_instructor: bool,
    pub org_address: ContractAddress,
    pub bootcamp_id: u64,
}

#[derive(Drop, starknet::Event)]
pub struct BootcampRegistration {
    pub org_address: ContractAddress,
    pub bootcamp_id: u64,
}

#[derive(Drop, starknet::Event)]
pub struct RegistrationApproved {
    pub student_address: ContractAddress,
    pub bootcamp_id: u64,
}

#[derive(Drop, starknet::Event)]
pub struct RegistrationDeclined {
    pub student_address: ContractAddress,
    pub bootcamp_id: u64,
}

#[derive(Drop, starknet::Event)]
pub struct AttendanceMarked {
    pub org_address: ContractAddress,
    pub instructor_address: ContractAddress,
    pub class_id: u64,
}

#[derive(Drop, starknet::Event)]
pub struct StudentsCertified {
    pub org_address: ContractAddress,
    pub class_id: u64,
    pub student_addresses: Array<ContractAddress>,
}

#[derive(Drop, starknet::Event)]
pub struct SponsorshipAddressSet {
    pub sponsor_contract_address: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct OrganizationSponsored {
    pub organization_address: ContractAddress,
    pub sponsor_uri: ByteArray,
    pub sponsorship_amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct SponsorshipFundWithdrawn {
    pub withdrawal_amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct OrganizationSuspended {
    pub org_contract_address: ContractAddress,
    pub org_name: ByteArray,
    pub suspended: bool,
}

#[derive(Drop, starknet::Event)]
pub struct BootCampSuspended {
    pub org_contract_address: ContractAddress,
    pub bootcamp_id: u64,
    pub bootcamp_name: ByteArray,
    pub suspended: bool,
}
