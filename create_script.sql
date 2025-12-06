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

-- Добавил каскады на случай удаления
CREATE TABLE linking_users_to_groups (
	group_id INT REFERENCES groups(id) ON DELETE CASCADE ON UPDATE CASCADE,
	user_id INT REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
	PRIMARY KEY (user_id, group_id) -- Поменял порядок для оптимизации процедуры по удалению 
);

CREATE TABLE linking_users_to_arms (
	user_id INT REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
	arm_id INT REFERENCES arm(id) ON DELETE CASCADE ON UPDATE CASCADE,
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
-- На миро была сложная версия, которую Зыков вообще не видел, он принял простую с тремя табличками
CREATE TABLE archive_license (
	id INT NOT NULL,
	archived_at TIMESTAMP DEFAULT now()::timestamp,
	name VARCHAR(100) NOT NULL,
	license_server_id INT REFERENCES license_server(id) ON DELETE SET NULL ON UPDATE CASCADE,
	port INT NOT NULL,
	responsible_user_id INT REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
	max_booking_period INTERVAL NOT NULL,
	PRIMARY KEY(id, archived_at)
);

CREATE TABLE archive_users (
	id INT NOT NULL,
	archived_at TIMESTAMP DEFAULT now()::timestamp,
	name VARCHAR(100) NOT NULL,
	email VARCHAR(100) NOT NULL,
	SAM_account_name VARCHAR(100) NOT NULL,
	employee_id VARCHAR(4) NOT NULL,
	is_editor BOOL NOT NULL,
	org_struct_id INT NOT NULL ON DELETE SET NULL ON UPDATE CASCADE,
	PRIMARY KEY (id, archived_at)
);

CREATE TABLE archive_license_obj_catalog (
	id INT NOT NULL,
	archived_at TIMESTAMP DEFAULT now()::timestamp,
	license_metric_type eLicensing_metric_type NOT NULL,
	licensing_type eLicensing_type NOT NULL,
	object_type eObject_type NOT NULL,
	max_possible_version VARCHAR(50) NOT NULL,
	current_version VARCHAR(50) NOT NULL,
	software_id INT REFERENCES software_catalog(id) ON DELETE CASCADE ON UPDATE CASCADE,
	package_id INT REFERENCES package_catalog(id) ON DELETE CASCADE ON UPDATE CASCADE,
	module_id INT REFERENCES module_catalog(id) ON DELETE CASCADE ON UPDATE CASCADE,
	key_type eKey_type NOT NULL,
	max_activations INT NOT NULL,
	max_concurrent INT NOT NULL,
	PRIMARY KEY (id, archived_at)
);


-- =====================TRIGGERS=====================
-- ТРИГГЕР ДЛЯ ПРОВЕРКИ ИЕРАРХИИ В ТАБЛИЦЕ ОРГАНИЗАЦИЙ
-- Триггер норм
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
	SELECT DISTINCT ON (l.id)
		l.id,
		l.name,
		l.license_server_id,
		l.port,
		l.responsible_user_id,
		l.max_booking_period
	FROM license AS l 
	JOIN purchase AS p ON l.id = p.license_id
	JOIN purchase_dates AS pd ON p.id = pd.purchase_id
	WHERE pd.date_type = 'license'::eDate_type AND now()::date <= pd.ends_at;

-- ТРИГГЕР ДЛЯ АРХИВАЦИИ ТАБЛИЦЫ ПОЛЬЗОВАТЕЛЕЙ
-- Норм
CREATE OR REPLACE FUNCTION users_archiver()
RETURNS trigger AS
$$
BEGIN
	INSERT INTO archive_users 
	(name, email, SAM_account_name, employee_id, is_editor, org_struct_id)
	VALUES 
	(OLD.name, OLD.email, OLD.SAM_account_name, OLD.employee_id, OLD.is_editor, OLD.org_struct_id);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;

CREATE trigger users_archiver_trigger
AFTER UPDATE OR DELETE on users
FOR EACH ROW
EXECUTE FUNCTION users_archiver();


-- =====================LICENSE_OBJ OPS=====================
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
-- Некит: тут некоторые атрибуты удалил, которые нельзя будет менять 
CREATE OR REPLACE PROCEDURE update_license_obj (
	p_id INT,
	p_licensing_metric_type eLicensing_metric_type DEFAULT NULL,
	p_licensing_type eLicensing_type DEFAULT NULL,
	p_max_possible_version VARCHAR(50) DEFAULT NULL,
	p_current_version VARCHAR(50) DEFAULT NULL,
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
		max_possible_version = COALESCE (p_max_possible_version, max_possible_version),
		current_version = COALESCE (p_current_version, current_version),
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
 
-- =====================Purchases=====================
-- ПРОЦЕДУРЫ ДЛЯ ПОКУПОК

-- ИЗМЕНИТЬ ДАТУ УВЕДОМЛЕНИЙ
CREATE OR REPLACE PROCEDURE update_notification_date (p_id INT, p_date_type eDate_type, p_date DATE) AS
$$
BEGIN
	UPDATE purchase_dates SET start_notifying_at = p_date WHERE purchase_id = p_id AND date_type = p_date_type;
END;
$$
LANGUAGE plpgsql;

/* Некит: 
я сделал так, потому что у нас будет сразу пачка документов/дат, 
которые мы передаём как аргумент.
вообще вариант достаточно жопошный, так как я в SQLModel 
не нашел чёткого синтаксиса по вызову процедур 
с такими сложными структурами
Вот что мне иишка выдала, но я ей не верю: 
from sqlalchemy.dialects.postgresql import composite
from sqlmodel import Session, create_engine

engine = create_engine("postgresql+psycopg2://user:pass@localhost/dbname")

MyType = composite("my_type", engine, ["id", "name"])
	
from sqlmodel import Session

def call_process_things(items: list[dict]):
    with Session(engine) as session:
        # Build composite instances
        pg_items = [MyType(i["id"], i["name"]) for i in items]

        session.exec(
            "SELECT process_things(:things)",
            {"things": pg_items}
        )
        session.commit()

*/

-- Пока пусть типы тут повесят, чтобы удобно было сверяться, потом их на верх закинем
-- Вообще составные типы удобная штука, но все их атрибуты могут быть NULL, 
-- главная их проблема

-- И ещё я не придумал пока как называть эти типы, чтобы они отличались от других

CREATE TYPE tDocument AS (
	doc_no INT,
	name VARCHAR(100),
	signing_date DATE,
	directum_link VARCHAR(100),
	status eStatus,
	document_type eDocument_type,
);

CREATE TYPE tPurchase_date AS (
	/* 
		Это поле скрываем, потому что у нас в процедурах уже будет переменная, 
		которые является айдишкой покупки 
		purchase_id INT NOT NULL REFERENCES purchase(id),
	*/
	date_type eDate_type,
	starts_at DATE,
	ends_at DATE,
	start_notifying_at DATE,
);

-- СОЗДАЕТ ПОЛНУЮ ПОКУПКУ С ДОКУМЕНТАМИ И ДАТАМИ
CREATE OR REPLACE PROCEDURE create_purchase (
	--purchase
	p_license_id INT,
	p_purchase_object ePurchase_object,
	p_purchased_at TIMESTAMP,
	p_count INT,

	-- Наборы объектов
	p_documents tDocument[],
	p_purchase_dates tPurchase_date[]
) AS
$$
DECLARE
	new_purchase_id INT;
BEGIN
	IF array_length(p_documents) < 1 THEN
		RAISE EXCEPTION 'p_documents must have at least 1 element';	
	END IF;

	IF array_length(p_purchase_dates) < 1 OR array_length(p_purchase_dates) > 3 THEN
		RAISE EXCEPTION 'p_purchase_dates length must be in 1..3';
	END IF;

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

	FOREACH doc IN ARRAY p_documents
	LOOP
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
			doc.doc_no,
			doc.name,
			doc.signing_date,
			doc.directum_link,
			doc.status,
			doc.document_type
		);
	END LOOP;

	FOREACH pd IN ARRAY p_purchase_dates
	LOOP
		INSERT INTO purchase_dates (
			purchase_id,
			date_type,
			starts_at,
			ends_at,
			start_notifying_at
		) VALUES (
			new_purchase_id,
			pd.date_type,
			pd.starts_at,
			pd.ends_at,
			pd.start_notifying_at
		);
	END LOOP;
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
	
	p_documents tDocument[],
	p_purchase_dates tPurchase_date[]
) AS
$$
BEGIN
	UPDATE purchase SET is_planned = false WHERE id = p_id;
	
	FOREACH doc IN ARRAY p_documents
	LOOP
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
			doc.doc_no,
			doc.name,
			doc.signing_date,
			doc.directum_link,
			doc.status,
			doc.document_type
		);
	END LOOP;

	FOREACH pd IN ARRAY p_purchase_dates
	LOOP
		INSERT INTO purchase_dates (
			purchase_id,
			date_type,
			starts_at,
			ends_at,
			start_notifying_at
		) VALUES (
			p_id,
			pd.date_type,
			pd.starts_at,
			pd.ends_at,
			pd.start_notifying_at
		);
	END LOOP;
END;
$$
LANGUAGE plpgsql;


-- =====================Company, soft, package, module=====================

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

-- =====================GROUP=====================

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
	-- Я добавил каскады, которые будут чистить связи в linking таблицах
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

-- =====================ARM=====================

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
	-- Я добавил каскады, которые будут чистить связи в linking таблицах
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

-- =====================LICENSE OPS=====================
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
		RAISE EXCEPTION 'no subject passed';
	ELSEIF subject_amount > 1 THEN
		RAISE EXCEPTION 'too many subjects passed';
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

-- СОЗДАНИЕ БРОНИ
-- скорее всего стоит добавить проверку на пересечение броней я не разобрался
CREATE PROCEDURE create_booking(
	p_reestr_id INT,
	p_booking_start TIMESTAMP,
	p_duration INTERVAL
) AS
$$
DECLARE
    v_max_end TIMESTAMP;
	v_booking_does_fit BOOLEAN;
	v_max_booking_period INTERVAL;
BEGIN
	SELECT max_booking_period INTO v_max_booking_period 
	FROM reestr JOIN license ON license.id = reestr.license_id
	WHERE reestr.id = p_reestr_id;

	IF v_max_booking_period IS NULL THEN
		RAISE EXCEPTION 'no record found';
	END IF;
	
	IF p_duration > v_max_booking_period THEN
		RAISE EXCEPTION 'booking duration cant be more than max license duration';
	END IF;
	

    SELECT 
        MAX(b.booking_start + b.duraition) INTO v_max_end
    FROM booking AS b
    WHERE b.reestr_id = p_reestr_id;
    /*
	Проверка на возможность вставки
	Посмотрим где лежит новая бронь:
		1) Между бронью, p_booking_start < max(start + dur) 
		2) после брони, p_booking_start >= max(start + dur)
	*/
	-- (1) Проверка на подходящий интервал
    --     Интервалы в прошлом будут отбрасываться
    IF p_booking_start < v_max_end THEN
        -- Подумать о переносе этого страха в функцию
        WITH cte AS (
            SELECT 
                b.booking_start,
                b.booking_start + b.duraition AS booking_end,
                lead(b.booking_start, 1) OVER (
                    ORDER BY b.booking_start 
                ) AS next_start
            FROM booking AS b
            WHERE 
                b.reestr_id = p_reestr_id AND
                b.booking_start::date >= now()::date -- date потому что timestamp слишком точный могут возникнуть проблемы
                                                -- а условие это нужно для отбрасывания того, что у нас в прошлом
        )
        SELECT EXISTS(
            SELECT 1
            FROM cte
            WHERE
                cte.next_start IS NOT NULL AND -- скипаем последнюю строчку
                cte.booking_end <= p_booking_start AND
                (p_booking_start + p_duration) <= cte.next_start
        ) INTO v_booking_does_fit;
            
        IF v_booking_does_fit THEN 
            INSERT INTO booking (reestr_id, booking_start, duration)
            VALUES (p_reestr_id, p_booking_start, p_duration);
        ELSE
            RAISE EXCEPTION 'there is no suitable interval inbetween existing bookings';
        END IF;
	-- (2) Просто добавляем как есть  
	ELSE
        INSERT INTO booking (reestr_id, booking_start, duration)
        VALUES (p_reestr_id, p_booking_start, p_duration);
    END IF;
END;
$$
LANGUAGE plpgsql;
