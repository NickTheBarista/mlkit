-- $Id$

-- This code i a down-sized and modified version of the party module found
-- in openACS (www.openacs.org): file community-core-create.sql.

create table scs_parties (
  party_id integer
    constraint scs_parties_party_id_nn not null
    constraint scs_parties_pk primary key,
  party_type varchar(100)
    constraint scs_parties_party_type_ck
      check(party_type in ('scs_persons','scs_groups')),
  email	varchar2(100)
    constraint scs_parties_email_un unique,
  url varchar2(200),
  last_modified date default sysdate 
    constraint scs_parties_last_modified_nn not null,
  modifying_user integer,
  deleted_p char(1) default 'f'
    constraint scs_parties_deleted_p_nn not null
    constraint scs_parties_deleted_p_ck check (deleted_p in ('t','f'))
);

comment on table scs_parties is '
 Party is the supertype of person and organization. It exists because
 many other types of object can have relationships to scs_parties.
';

comment on column scs_parties.url is '
 We store url here so that we can always make party names hyperlinks
 without joining to any other table.
';

-- DRB: I added this trigger to enforce the storing of e-mail in lower
-- case.  party.new() already did so but I found an update that
-- didn't...  Also, we makes sure that email is never null. This may
-- happen otherwise because we do not always know email-addresses on
-- persons we create.

create or replace trigger scs_parties_in_up_tr
before insert or update on scs_parties
for each row
begin
  :new.email := lower(:new.email);
  if :new.email is null then
    :new.email := :new.party_id;
  end if;
end;
/
show errors


-------------------
-- PARTY PACKAGE --
-------------------

create or replace package scs_party
as
  function new (
    party_id	   in scs_parties.party_id%TYPE default null,
    party_type     in scs_parties.party_type%TYPE default null,
    email	   in scs_parties.email%TYPE default null,
    url		   in scs_parties.url%TYPE default null,
    last_modified  in scs_parties.last_modified%TYPE default sysdate,
    modifying_user in scs_parties.modifying_user%TYPE default null,
    deleted_p      in scs_parties.deleted_p%TYPE default 'f'
  ) return scs_parties.party_id%TYPE;

  procedure destroy (
    party_id in scs_parties.party_id%TYPE
  );

  function email (
    party_id in scs_parties.party_id%TYPE
  ) return scs_parties.email%TYPE;

  function url (
    party_id in scs_parties.party_id%TYPE
  ) return scs_parties.url%TYPE;

end scs_party;
/
show errors

create or replace package body scs_party
as
  function new (
    party_id	   in scs_parties.party_id%TYPE default null,
    party_type     in scs_parties.party_type%TYPE default null,
    email	   in scs_parties.email%TYPE default null,
    url		   in scs_parties.url%TYPE default null,
    last_modified  in scs_parties.last_modified%TYPE default sysdate,
    modifying_user in scs_parties.modifying_user%TYPE default null,
    deleted_p      in scs_parties.deleted_p%TYPE default 'f'
  )
  return scs_parties.party_id%TYPE
  is
    v_party_id scs_parties.party_id%TYPE;
  begin
    v_party_id := scs.new_obj_id(party_id);

    insert into scs_parties (party_id, party_type, email, url)
      values (v_party_id, party_type, lower(email), url);

    return v_party_id;
  end new;

  procedure destroy (
    party_id in scs_parties.party_id%TYPE
  )
  is
    v_deleted_p		char(1);
  begin
    select deleted_p into v_deleted_p
    from scs_parties
    where scs_parties.party_id = scs_party.destroy.party_id;

    if( v_deleted_p = 'f' ) then
      update scs_parties
         set deleted_p = 't',
             email = to_char(party_id) || '-' || email
       where scs_parties.party_id = scs_party.destroy.party_id;
    end if;
  end destroy;

  function email (
    party_id in scs_parties.party_id%TYPE
  ) return scs_parties.email%TYPE
  is
    v_email scs_parties.email%TYPE;
  begin
    select email
      into v_email
      from scs_parties
     where party_id = email.party_id;

    return v_email;
 end email;

  function url (
    party_id in scs_parties.party_id%TYPE
  ) return scs_parties.url%TYPE
  is
    v_url scs_parties.url%TYPE;
  begin
    select url
      into v_url
      from scs_parties
     where party_id = url.party_id;

    return v_url;
 end url;

end scs_party;
/
show errors

