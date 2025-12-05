CREATE TYPE eDate_type AS ENUM ('support', 'license', 'document');
CREATE TYPE eStatus AS ENUM ('active', 'cancelled', 'terminated');
CREATE TYPE eDocument_type AS ENUM ('support', 'license');
CREATE TYPE ePurchase_object AS ENUM ('license', 'support', 'extended_support', 'subscription');
CREATE TYPE eLicensing_metric_type AS ENUM ('per_subject', 'concurrent', 'arm', 'core', 'token', 'login');
CREATE TYPE eLicensing_type AS ENUM ('client_local', 'client_network', 'configuration', 'server', 'mobile');
CREATE TYPE eObject_type AS ENUM ('software', 'module', 'package');
CREATE TYPE eKey_type AS ENUM ('physical', 'virtual');
CREATE TYPE eLanguage AS ENUM ('russian', 'french', 'english', 'multilingual', 'other');
CREATE TYPE eSystem_architecture AS ENUM ('x64/x86', 'x64', 'x86', 'ARM', 'RISCV'); -- x64 обратно совместим с x86, какой смысл от 'x64/x86'?
																					-- У него в эксельке в разрядности системы так было, я решил оставить на всякий
CREATE TYPE eOrg_type AS ENUM ('organization', 'department', 'division');
CREATE TYPE eArm_type AS ENUM ('server', 'physical_machine', 'virtual_machine', 'mixed_machine');
CREATE TYPE eLink_type AS ENUM ('user', 'arm', 'group');


CREATE TABLE arm (
	id SERIAL PRIMARY KEY,
	name VARCHAR(100) NOT NULL CHECK (name ~ '^[a-zA-Z0-9-]+$'),
	arm_type eArm_type NOT NULL
);

CREATE TABLE org_struct (
	id SERIAL PRIMARY KEY,
	parent_id INT REFERENCES org_struct(id),
	name VARCHAR(100) NOT NULL CHECK (name ~ '^[а-яА-ЯйЙa-zA-Z ]+$'),
	org_type eOrg_type NOT NULL
);

CREATE TABLE groups (
	id SERIAL PRIMARY KEY,
	name VARCHAR(100) NOT NULL CHECK (name ~ '^[а-яА-ЯйЙa-zA-Z ]+$')
);

CREATE TABLE users (
	id SERIAL PRIMARY KEY,
	name VARCHAR(100) NOT NULL CHECK (name ~ '^[а-яА-ЯйЙ ]+$'),
	email VARCHAR(100) NOT NULL CHECK (email ~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'),
	SAM_account_name VARCHAR(100) NOT NULL CHECK (SAM_account_name ~ '^[a-zA-Z]+$'),
	employee_id VARCHAR(4) NOT NULL CHECK (employee_id ~ '^[0-9]+$'),
	is_editor BOOL NOT NULL,
	org_struct_id INT NOT NULL REFERENCES org_struct(id)
);

CREATE TABLE linking_users_to_groups (
	group_id INT REFERENCES groups(id),
	user_id INT REFERENCES users(id),
	PRIMARY KEY (group_id, user_id)
);

CREATE TABLE linking_users_to_arms (
	user_id INT REFERENCES users(id),
	arm_id INT REFERENCES arm(id),
	PRIMARY KEY (user_id, arm_id)
);

CREATE TABLE company_catalog (
	id SERIAL PRIMARY KEY,
	name VARCHAR(100) NOT NULL CHECK (name ~ '^[a-zA-Z0-9-]+$'),
	is_domestic BOOL NOT NULL,
	website VARCHAR(100) CHECK (website ~ '^(https?:\/\/)?(www.)?[a-z0-9]+\.[a-z]+(\/[a-zA-Z0-9#]+\/?)*$')
);

CREATE TABLE software_catalog (
	id SERIAL PRIMARY KEY,
	company_id INT NOT NULL REFERENCES company_catalog(id),
	is_standalone BOOL NOT NULL,
	name VARCHAR(100) NOT NULL CHECK (name ~ '^[а-яА-ЯйЙa-zA-Z0-9]+$'),
	functionality_description VARCHAR(300) NOT NULL,
	language eLanguage NOT NULL,
	system_architecture eSystem_architecture NOT NULL
);

CREATE TABLE package_catalog (
	id SERIAL PRIMARY KEY,
	software_id INT NOT NULL REFERENCES software_catalog(id),
	name VARCHAR(100) NOT NULL CHECK (name ~ '^[а-яА-ЯйЙa-zA-Z0-9]+$'),
	unique_id VARCHAR(100) NOT NULL CHECK (unique_id ~ '^[a-zA-Z0-9]+$') -- TODO: спросить зыкова про формат, но кажется ранее он говорил про буквы и цифры
);

CREATE TABLE module_catalog (
	id SERIAL PRIMARY KEY,
	software_id INT NOT NULL REFERENCES software_catalog(id),
	articul VARCHAR(100) NOT NULL CHECK (articul ~ '^[а-яА-ЯйЙa-zA-Z0-9-]+$'),
	name VARCHAR(100) NOT NULL CHECK (name ~ '^[а-яА-ЯйЙa-zA-Z0-9]+$'),
	functionality_description VARCHAR(300) NOT NULL
);

CREATE TABLE license_obj_catalog (
	id SERIAL PRIMARY KEY,
	license_metric_type eLicensing_metric_type NOT NULL,
	licensing_type eLicensing_type NOT NULL,
	object_type eObject_type NOT NULL,
	max_possible_version VARCHAR(50) NOT NULL CHECK (max_possible_version ~ '^[0-9.]+$'),
	current_version VARCHAR(50) NOT NULL CHECK (current_version ~ '^[0-9.]+$'),
	software_id INT UNIQUE REFERENCES software_catalog(id),
	package_id INT UNIQUE REFERENCES package_catalog(id),
	module_id INT UNIQUE REFERENCES module_catalog(id),
	key_type eKey_type NOT NULL,
	max_activations INT NOT NULL CHECK (max_activations >= 0),
	max_concurrent INT NOT NULL CHECK (max_concurrent >= 0),
	CONSTRAINT chk_obj_types CHECK(
		(
			object_type = 'software'::eObject_type AND 
			software_id IS NOT NULL AND 
			package_id IS NULL AND 
			module_id IS NULL
		)::int + 
		(
			object_type = 'package'::eObject_type AND 
			software_id IS NULL AND 
			package_id IS NOT NULL AND 
			module_id IS NULL
		)::int + 
		(
			object_type = 'module'::eObject_type AND 
			software_id IS NULL AND 
			package_id IS NULL AND 
			module_id IS NOT NULL
		)::int = 1
	)
);

CREATE TABLE linking_module_to_package (
	package_id INT REFERENCES package_catalog(id),
	module_id INT REFERENCES module_catalog(id),
	PRIMARY KEY (package_id, module_id)
);

CREATE TABLE license_server (
	id SERIAL PRIMARY KEY,
	name VARCHAR(100) NOT NULL CHECK (name ~ '^[a-zA-Z0-9-]+$'),
	hostname VARCHAR(100) NOT NULL CHECK (hostname ~ '^[a-zA-Z0-9-]+$'),
	ip INET NOT NULL --  built-in ipv4\v6 type
);

CREATE TABLE license (
	id SERIAL PRIMARY KEY,
	name VARCHAR(100) NOT NULL CHECK (name ~ '^[а-яА-ЯйЙa-zA-Z0-9. ]+$'),
	license_server_id INT NOT NULL REFERENCES license_server(id),
	port INT NOT NULL CHECK (port <= 65535 AND port >= 0),
	responsible_user_id INT NOT NULL REFERENCES users(id),
	max_booking_period INTERVAL NOT NULL
);

CREATE TABLE linking_license_obj_to_license (
	license_id INT NOT NULL REFERENCES license(id),
	license_obj_id INT NOT NULL REFERENCES license_obj_catalog(id),
	PRIMARY KEY (license_id, license_obj_id)
);

CREATE TABLE purchase (
	id SERIAL PRIMARY KEY,
	license_id INT NOT NULL REFERENCES license(id),
	purchase_object ePurchase_object NOT NULL,
	purchased_at TIMESTAMP NOT NULL,
	count INT NOT NULL CHECK (count >= 0),
	is_planned BOOL NOT NULL
);

CREATE TABLE purchase_dates (
	purchase_id INT NOT NULL REFERENCES purchase(id),
	date_type eDate_type NOT NULL,
	starts_at DATE NOT NULL,
	ends_at DATE,
	start_notifying_at DATE,
	PRIMARY KEY (purchase_id, date_type),
	CONSTRAINT chk_starts_ends_dates CHECK ( 
		(ends_at IS NULL) OR 
		(starts_at <= ends_at) 
	),
	CONSTRAINT chk_ends_notifying_dates CHECK ( 
		(start_notifying_at IS NULL) OR 
		( 
			starts_at <= start_notifying_at AND
			(
				(ends_at IS NULL) OR (start_notifying_at <= ends_at)
			) 
		)
	)
);

CREATE TABLE document (
	id SERIAL PRIMARY KEY,
	purchase_id INT NOT NULL REFERENCES purchase(id),
	doc_no INT NOT NULL CHECK (doc_no >= 0),
	name VARCHAR(100) NOT NULL CHECK (name ~ '^[а-яА-ЯйЙa-zA-Z0-9-=№ ]+$'),
	signing_date DATE NOT NULL,
	directum_link VARCHAR(100) NOT NULL,
	status eStatus NOT NULL,
	document_type eDocument_type
);

CREATE TABLE reestr (
	id SERIAL PRIMARY KEY,
	link_type eLink_type NOT NULL,
	license_id INT NOT NULL UNIQUE REFERENCES license(id),
	group_id INT UNIQUE REFERENCES groups(id),
	user_id INT UNIQUE REFERENCES users(id),
	arm_id INT UNIQUE REFERENCES arm(id),
	CONSTRAINT chk_link_types CHECK (
		(
			link_type = 'group'::eLink_type AND 
			group_id IS NOT NULL AND 
			user_id IS NULL AND 
			arm_id IS NULL
		)::int + 
		(
			link_type = 'user'::eLink_type AND 
			group_id IS NULL AND 
			user_id IS NOT NULL AND 
			arm_id IS NULL
		)::int + 
		(
			link_type = 'arm'::eLink_type AND 
			group_id IS NULL AND 
			user_id IS NULL AND 
			arm_id IS NOT NULL
		)::int = 1
	)
);

CREATE TABLE booking (
	id SERIAL PRIMARY KEY,
	reestr_id INT NOT NULL REFERENCES reestr(id),
	booking_start TIMESTAMP NOT NULL,
	duration INTERVAL NOT NULL
);

-- ARCHIVES 

CREATE TABLE archive_license (
	id INT PRIMARY KEY,
	name VARCHAR(100) NOT NULL,
	archived_at TIMESTAMP DEFAULT now()::timestamp,
	port INT NOT NULL,
	max_booking_period INTERVAL NOT NULL
);

CREATE TABLE archive_purchase (
	id INT PRIMARY KEY,
	archive_license_id INT NOT NULL REFERENCES archive_license(id),
	purchase_object ePurchase_object NOT NULL,
	purchase_at TIMESTAMP NOT NULL,
	count INT NOT NULL
);

CREATE TABLE archive_document (
	id INT PRIMARY KEY,
	archive_purchase_id INT NOT NULL REFERENCES archive_purchase(id),
	doc_no INT NOT NULL,
	name VARCHAR(100) NOT NULL,
	signing_date DATE NOT NULL,
	directum_link VARCHAR(100) NOT NULL,
	status eStatus NOT NULL,
	document_type eDocument_type NOT NULL
);

CREATE TABLE archive_purchase_dates (
	archive_purchase_id INT NOT NULL REFERENCES archive_purchase(id),
	date_type eDate_type NOT NULL,
	starts_at DATE NOT NULL,
	ends_at DATE,
	start_notifying_at DATE,
	PRIMARY KEY (archive_purchase_id, date_type)
);

CREATE TABLE linking_license_obj_to_archive_license (
	license_obj_id INT REFERENCES license_obj_catalog(id),
	archive_license_id INT REFERENCES archive_license(id),
	PRIMARY KEY (license_obj_id, archive_license_id)
);

-- тут скорее всего херня некит проверь пж
-- maybe add user_id/original_user_id
CREATE TABLE archive_users (
	id SERIAL PRIMARY KEY,
	archived_at TIMESTAMP DEFAULT now()::timestamp,
	name VARCHAR(100) NOT NULL,
	email VARCHAR(100) NOT NULL,
	SAM_account_name VARCHAR(100) NOT NULL,
	employee_id VARCHAR(4) NOT NULL,
	is_editor BOOL NOT NULL,
	org_struct_id INT NOT NULL
);

-- END CREATE TABLE


-- ТРИГГЕР ДЛЯ ПРОВЕРКИ ИЕРАРХИИ В ТАБЛИЦЕ ОРГАНИЗАЦИЙ

CREATE OR REPLACE FUNCTION org_hierarchy_checker()
RETURNS trigger AS
$$
DECLARE 
	parent_org_type eOrg_type;
BEGIN

	SELECT org_type INTO parent_org_type FROM org_struct WHERE id = NEW.parent_id;
	
	IF NEW.org_type = 'organization' THEN
		IF NEW.parent_id IS NOT NULL THEN
			RAISE EXCEPTION 'for this org_type parent_id must be null';		
		END IF;
		RETURN NEW;
	END IF;

	IF NEW.parent_id IS NULL THEN
		RAISE EXCEPTION 'org_type must have a parent';
	END IF;	
		
	IF NEW.org_type = 'department' AND parent_org_type != 'organization' THEN
		RAISE EXCEPTION 'org_type of parent must be "organization"';
	END IF;

	IF NEW.org_type = 'division' AND parent_org_type != 'department' THEN
		RAISE EXCEPTION 'org_type of parent must be "department"';
	END IF;

	RETURN NEW;
END;
$$
LANGUAGE plpgsql;

CREATE trigger org_hierarchy_trigger
BEFORE INSERT ON org_struct
FOR EACH ROW
EXECUTE FUNCTION org_hierarchy_checker();


-- VIEW ДЛЯ АКТИВНЫХ ЛИЦЕНЗИЙ
CREATE VIEW active_licenses AS
	SELECT license.id, license.name, license_server_id, port, responsible_user_id, max_booking_period 
	FROM license 
		JOIN purchase ON license.id = purchase.license_id
			JOIN document ON purchase.id = document.purchase_id
			WHERE document.status = 'active';

-- ТРИГГЕР ДЛЯ АРХИВАЦИИ ТАБЛИЦЫ ПОЛЬЗОВАТЕЛЕЙ
CREATE OR REPLACE FUNCTION users_archiver()
RETURNS trigger AS
$$
BEGIN
	INSERT INTO archive_users (name, email, SAM_account_name, employee_id, is_editor, org_struct_id)
	VALUES (OLD.name, OLD.email, OLD.SAM_account_name, OLD.employee_id, OLD.is_editor, OLD.org_struct_id);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;

CREATE trigger users_archiver_trigger
AFTER UPDATE OR DELETE on users
FOR EACH ROW
EXECUTE FUNCTION users_archiver();


-- license obj procedures

CREATE OR REPLACE PROCEDURE create_license_obj (
	p_licensing_metric_type eLicensing_metric_type,
	p_licensing_type eLicensing_type,
	p_object_type eObject_type,
	p_max_possible_version VARCHAR(50),
	p_current_version VARCHAR(50),
	p_software_id INT,
	p_package_id INT,
	p_module_id INT,
	p_key_type eKey_type,
	p_max_activations INT,
	p_max_concurrent INT
) AS
$$
BEGIN
	INSERT INTO license_obj_catalog (
		license_metric_type,
		licensing_type,
		object_type,
		max_possible_version,
		current_version,
		software_id,
		package_id,
		module_id,
		key_type,
		max_activations,
		max_concurrent
	)
	VALUES (
		p_licensing_metric_type,
        p_licensing_type,
        p_object_type,
        p_max_possible_version,
        p_current_version,
        p_software_id,
        p_package_id,
        p_module_id,
        p_key_type,
        p_max_activations,
        p_max_concurrent
	);
END;
$$
LANGUAGE plpgsql;


-- call update_license_obj (arg => val);
CREATE OR REPLACE PROCEDURE update_license_obj (
	p_id INT,
	p_licensing_metric_type eLicensing_metric_type DEFAULT NULL,
	p_licensing_type eLicensing_type DEFAULT NULL,
	p_object_type eObject_type DEFAULT NULL,
	p_max_possible_version VARCHAR(50) DEFAULT NULL,
	p_current_version VARCHAR(50) DEFAULT NULL,
	p_software_id INT DEFAULT NULL,
	p_package_id INT DEFAULT NULL,
	p_module_id INT DEFAULT NULL,
	p_key_type eKey_type DEFAULT NULL,
	p_max_activations INT DEFAULT NULL,
	p_max_concurrent INT DEFAULT NULL
) AS
$$
BEGIN
	UPDATE license_obj
	SET
		license_metric_type = COALESCE (p_licensing_metric_type, license_metric_type),
		licensing_type = COALESCE (p_licensing_type, licensing_type),
		object_type = COALESCE (p_object_type, object_type),
		max_possible_version = COALESCE (p_max_possible_version, max_possible_version),
		current_version = COALESCE (p_current_version, current_version),
		software_id = COALESCE (p_software_id, software_id),
		package_id = COALESCE (p_package_id, package_id),
		module_id = COALESCE (p_module_id, module_id),
		key_type = COALESCE (p_key_type, key_type),
		max_activations = COALESCE (p_max_activations, max_activations),
		max_concurrent = COALESCE (p_max_concurrent, max_concurrent)
	WHERE id = p_id;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE delete_license_obj (p_id INT) AS
$$
BEGIN
	DELETE FROM license_obj WHERE id = p_id;
END;
$$
LANGUAGE plpgsql;
 
-- ПРОЦЕДУРЫ ДЛЯ ПОКУПОК

-- ИЗМЕНИТЬ ДАТУ УВЕДОМЛЕНИЙ
CREATE OR REPLACE PROCEDURE update_notification_date (p_id INT, p_date_type eDate_type, p_date DATE) AS
$$
BEGIN
	UPDATE purchase_dates SET start_notifying_at = p_date WHERE purchase_id = p_id AND date_type = p_date_type;
END;
$$
LANGUAGE plpgsql;


-- СОЗДАЕТ ПОЛНУЮ ПОКУПКУ С ДОКУМЕНТАМИ И ДАТАМИ
CREATE OR REPLACE PROCEDURE create_purchase (
	--purchase
	p_license_id INT,
	p_purchase_object ePurchase_object,
	p_purchased_at TIMESTAMP,
	p_count INT,
	
	--document
	p_doc_no INT,
	p_name VARCHAR(100),
	p_signing_date DATE,
	p_directum_link VARCHAR(100),
	p_status eStatus,
	p_document_type eDocument_type,
	
	--purchase_dates
	p_date_type eDate_type,
	p_starts_at DATE,
	p_ends_at DATE DEFAULT NULL,
	p_start_notifying_at DATE DEFAULT NULL
) AS
$$
DECLARE
	new_purchase_id INT;
BEGIN
	INSERT INTO purchase (
		license_id,
		purchase_object,
		purchased_at,
		count,
		is_planned
	) VALUES (
		p_license_id, 
        p_purchase_object, 
        p_purchased_at, 
        p_count, 
        false
	)
	RETURNING id INTO new_purchase_id;

	INSERT INTO document (
		purchase_id,
		doc_no,
		name,
		signing_date,
		directum_link,
		status,
		document_type
	) VALUES (
		new_purchase_id,
		p_doc_no,
		p_name,
		p_signing_date,
		p_directum_link,
		p_status,
		p_document_type
	);

	INSERT INTO purchase_dates (
		purchase_id,
		date_type,
		starts_at,
		ends_at,
		start_notifying_at
	) VALUES (
		new_purchase_id,
		p_date_type,
		p_starts_at,
		p_ends_at,
		p_start_notifying_at
	);
END;
$$
LANGUAGE plpgsql;

--СОЗДАНИЕ ПЛАНИРУЕМОЙ ПОКУПКИ
CREATE OR REPLACE PROCEDURE create_planned_purchase (
	p_license_id INT,
	p_purchase_object ePurchase_object,
	p_purchased_at TIMESTAMP,
	p_count INT
) AS
$$
BEGIN
	INSERT INTO purchase (license_id, purchase_object, purchased_at, count, is_planned)
	VALUES (p_license_id, p_purchase_object, p_purchased_at, p_count, true);
END;
$$
LANGUAGE plpgsql;

--ПЕРЕВОД ПОКУПКИ ИЗ ПЛАНИРУЕМОЙ В ОБЫЧНУЮ
CREATE OR REPLACE PROCEDURE finalise_purchase (
	--purchase_id
	p_id INT,
	
	--document
	p_doc_no INT,
	p_name VARCHAR(100),
	p_signing_date DATE,
	p_directum_link VARCHAR(100),
	p_status eStatus,
	p_document_type eDocument_type,
	
	--purchase_dates
	p_date_type eDate_type,
	p_starts_at DATE,
	p_ends_at DATE DEFAULT NULL,
	p_start_notifying_at DATE DEFAULT NULL
) AS
$$
BEGIN
	UPDATE purchase SET is_planned = false WHERE id = p_id;
	INSERT INTO document (
		purchase_id,
		doc_no,
		name,
		signing_date,
		directum_link,
		status,
		document_type
	) VALUES (
		p_id,
		p_doc_no,
		p_name,
		p_signing_date,
		p_directum_link,
		p_status,
		p_document_type
	);

	INSERT INTO purchase_dates (
		purchase_id,
		date_type,
		starts_at,
		ends_at,
		start_notifying_at
	) VALUES (
		p_id,
		p_date_type,
		p_starts_at,
		p_ends_at,
		p_start_notifying_at
	);
END;
$$
LANGUAGE plpgsql;


-- СОЗДАНИЕ РЕДАКТИРОВАНИЕ COMPANY

CREATE OR REPLACE PROCEDURE create_company (
	p_name VARCHAR(100),
	p_is_domestic BOOL,
	p_website VARCHAR(100)
) AS
$$
BEGIN
	INSERT INTO company_catalog (name, is_domestic, website)
	VALUES (p_name, p_is_domestic, p_website);
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE update_company (
	p_id INT,
	p_name VARCHAR(100) DEFAULT NULL,
	p_is_domestic BOOL DEFAULT NULL,
	p_website VARCHAR(100) DEFAULT NULL
) AS
$$
BEGIN
	UPDATE company_catalog SET
		name = COALESCE (p_name, name),
		is_domestic = COALESCE (p_is_domestic, is_domestic),
		website = COALESCE (p_website, website)
	WHERE id = p_id;
END;
$$
LANGUAGE plpgsql;

-- СОЗДАНИЕ РЕДАКТИРОВАНИЕ SOFTWARE

CREATE OR REPLACE PROCEDURE create_software (
    p_company_id INT,
    p_is_standalone BOOL,
    p_name VARCHAR(100),
    p_functionality_description VARCHAR(300),
    p_language eLanguage,
    p_system_architecture eSystem_architecture
) AS
$$
BEGIN
    INSERT INTO software_catalog (
        company_id, 
        is_standalone, 
        name, 
        functionality_description, 
        language, 
        system_architecture
    )
    VALUES (
        p_company_id, 
        p_is_standalone, 
        p_name, 
        p_functionality_description, 
        p_language, 
        p_system_architecture
    );
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE update_software (
    p_id INT,
    p_company_id INT DEFAULT NULL,
    p_is_standalone BOOL DEFAULT NULL,
    p_name VARCHAR(100) DEFAULT NULL,
    p_functionality_description VARCHAR(300) DEFAULT NULL,
    p_language eLanguage DEFAULT NULL,
    p_system_architecture eSystem_architecture DEFAULT NULL
) AS
$$
BEGIN
    UPDATE software_catalog SET
        company_id = COALESCE (p_company_id, company_id),
        is_standalone = COALESCE (p_is_standalone, is_standalone),
        name = COALESCE (p_name, name),
        functionality_description = COALESCE (p_functionality_description, functionality_description),
        language = COALESCE (p_language, language),
        system_architecture = COALESCE (p_system_architecture, system_architecture)
    WHERE id = p_id;
END;
$$
LANGUAGE plpgsql;


-- СОЗДАНИЕ РЕДАКТИРОВАНИЕ PACKAGE

CREATE OR REPLACE PROCEDURE create_package (
    p_software_id INT,
    p_name VARCHAR(100),
    p_unique_id VARCHAR(100)
) AS
$$
BEGIN
    INSERT INTO package_catalog (software_id, name, unique_id)
    VALUES (p_software_id, p_name, p_unique_id);
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE update_package (
    p_id INT,
    p_software_id INT DEFAULT NULL,
    p_name VARCHAR(100) DEFAULT NULL,
    p_unique_id VARCHAR(100) DEFAULT NULL
) AS
$$
BEGIN
    UPDATE package_catalog SET
        software_id = COALESCE (p_software_id, software_id),
        name = COALESCE (p_name, name),
        unique_id = COALESCE (p_unique_id, unique_id)
    WHERE id = p_id;
END;
$$
LANGUAGE plpgsql;


-- СОЗДАНИЕ MODULE

CREATE OR REPLACE PROCEDURE create_module (
    p_software_id INT,
    p_articul VARCHAR(100),
    p_name VARCHAR(100),
    p_functionality_description VARCHAR(300)
) AS
$$
BEGIN
    INSERT INTO module_catalog (
        software_id, 
        articul, 
        name, 
        functionality_description
    )
    VALUES (
        p_software_id, 
        p_articul, 
        p_name, 
        p_functionality_description
    );
END;
$$
LANGUAGE plpgsql;

-- CREATE GROUP
CREATE PROCEDURE create_group (
	p_name VARCHAR(100)
) AS
$$
BEGIN
	INSERT INTO groups (name) VALUES (p_name);
END;
$$
LANGUAGE plpgsql;

-- DELETE GROUP
-- что делать с fk
CREATE PROCEDURE delete_group (
	p_id INT
) AS
$$
BEGIN
	DELETE FROM groups WHERE id = p_id;
END;
$$
LANGUAGE plpgsql;

-- ADD USER TO GROUP
CREATE PROCEDURE group_add_user (
	p_user_id INT,
	p_group_id INT
) AS
$$
BEGIN
	INSERT INTO linking_user_to_groups VALUES (p_group_id, p_user_id);
END;
$$
LANGUAGE plpgsql;

-- REMOVE USER FROM GROUP
CREATE PROCEDURE group_delete_user (
	p_user_id INT,
	p_group_id INT
) AS
$$
BEGIN
	DELETE FROM linking_user_to_groups WHERE user_id = p_user_id AND group_id = p_group_id;
END;
$$
LANGUAGE plpgsql;


-- CREATE ARM
CREATE OR REPLACE PROCEDURE create_arm (
	p_name VARCHAR(100),
	p_arm_type eArm_type
) AS
$$
BEGIN
	INSERT INTO arm (name, arm_type) VALUES (p_name, p_arm_type);
END;
$$
LANGUAGE plpgsql;

-- DELETE ARM
-- также что делать с fk хз
CREATE OR REPLACE PROCEDURE delete_arm (
	p_id INT
) AS
$$
BEGIN
	DELETE FROM arm WHERE id = p_id;
END;
$$
LANGUAGE plpgsql;

-- ADD USER TO ARM
CREATE OR REPLACE PROCEDURE arm_add_user (
	p_user_id INT,
	p_arm_id INT
) AS
$$
BEGIN
	INSERT INTO linking_users_to_arms (arm_id, user_id) VALUES (p_arm_id, p_user_id);
END;
$$
LANGUAGE plpgsql;

-- REMOVE USER FROM ARM
CREATE OR REPLACE PROCEDURE arm_delete_user (
	p_user_id INT,
	p_arm_id INT
) AS
$$
BEGIN
	DELETE FROM linking_users_to_arms WHERE user_id = p_user_id AND arm_id = p_arm_id;
END;
$$
LANGUAGE plpgsql;

-- привязка лицензии к субъекту
CREATE PROCEDURE link_license_with (
	p_license_id INT,
	p_group_id INT DEFAULT NULL,
	p_arm_id INT DEFAULT NULL,
	p_user_id INT DEFAULT NULL
) AS
$$
DECLARE
	subject_amount INT;
	v_link_type eLink_type;
BEGIN
	subject_amount := (p_group_id IS NOT NULL)::int + (p_arm_id IS NOT NULL)::int  + (p_user_id IS NOT NULL)::int;

	IF subject_amount = 0 THEN
		RAISE EXCEPTION 'KYS no subject';
	ELSEIF subject_amount > 1 THEN
		RAISE EXCEPTION 'KYS too many subjects';
	END IF;

	IF p_group_id IS NOT NULL THEN
		v_link_type := 'group';
	ELSEIF p_arm_id IS NOT NULL THEN
		v_link_type := 'arm';
	ELSEIF p_user_id IS NOT NULL THEN
		v_link_type := 'user';
	END IF;

	INSERT INTO reestr (link_type, license_id, group_id, user_id, arm_id)
	VALUES (v_link_type, p_license_id, p_group_id, p_user_id, p_arm_id);
END;
$$
LANGUAGE plpgsql;