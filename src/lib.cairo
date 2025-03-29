pub mod contracts {
    pub mod AttenSysCourse;

    pub mod AttenSysEvent;
    // pub mod AttenSysOrg;
    pub mod AttenSysSponsor;
    pub mod AttenSysNft;
    pub mod AttenSysToken;
    pub mod mock;
    mod Registration;
    pub mod AttenSysOrg;
    // mod BootCampManagement;
}

pub mod interfaces {
    pub mod IAttenSysCourse;
    pub mod IAttenSysOrg;
}

pub mod base {
    pub mod types;
    pub mod storage_groups;
    pub mod event;
}

