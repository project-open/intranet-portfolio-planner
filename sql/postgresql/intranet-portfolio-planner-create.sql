-- /packages/intranet-portfolio-planner/sql/postgresql/intranet-portfolio-planner-create.sql
--
-- Copyright (c) 2010 ]project-open[
--
-- All rights reserved. Please check
-- http://www.project-open.com/license/ for details.
--
-- @author frank.bergmann@project-open.com


\i intranet-portfolio-planner-workflow-create.sql


SELECT im_menu__new (
	null,						-- p_menu_id
	'im_menu',					-- object_type
	now(),						-- creation_date
	null,						-- creation_user
	null,						-- creation_ip
	null,						-- context_id
	'intranet-portfolio-planner',			-- package_name
	'portfolio_planner',				-- label
	'Portfolio Planner',				-- name
	'/intranet-portfolio-planner/',			-- url
	0,						-- sort_order
	(select menu_id from im_menus where label = 'projects'),
	null						-- p_visible_tcl
);

SELECT acs_permission__grant_permission(
	(select menu_id from im_menus where label = 'portfolio_planner'),
	(select group_id from groups where group_name = 'Employees'),
	'read'
);



SELECT im_menu__new (
	null,						-- p_menu_id
	'im_menu',					-- object_type
	now(),						-- creation_date
	null,						-- creation_user
	null,						-- creation_ip
	null,						-- context_id
	'intranet-portfolio-planner',			-- package_name
	'reporting-portfolio-planner',				-- label
	'Portfolio Planner Report',				-- name
	'/intranet-portfolio-planner/index',		-- url
	0,						-- sort_order
	(select menu_id from im_menus where label = 'reporting-program-portfolio'),
	null						-- p_visible_tcl
);

SELECT acs_permission__grant_permission(
	(select menu_id from im_menus where label = 'reporting-portfolio-planner'),
	(select group_id from groups where group_name = 'Employees'),
	'read'
);



create or replace function inline_0 ()
returns integer as $$
declare
	v_menu			integer;
	v_portfolio_menu		integer;
	v_employees		integer;
BEGIN
	select group_id into v_employees from groups where group_name = 'Employees';
	select menu_id into v_portfolio_menu from im_menus where label = 'portfolio';
	v_menu := im_menu__new (
		null, 'im_menu', now(), null, null, null,	-- meta information
		'intranet-portfolio-planner',			-- package_name
		'portfolio_planner',				-- label
		'Portfolio Planner',				-- name
		'/intranet-portfolio-planner/index',		-- url
		15,						-- sort_order
		v_portfolio_menu,				-- parent_menu_id
		null						-- p_visible_tcl
	);
	PERFORM acs_permission__grant_permission(v_menu, v_employees, 'read');
	return 0;
end;$$ language 'plpgsql';
select inline_0 ();
drop function inline_0 ();


-- ------------------------------------------------------
-- Create a REST data-source for all PMs who have not yet updated their projects
-- According to the WF
-- ------------------------------------------------------

SELECT im_report_new (
	'REST Portfolio Planner Projects Update Cases',			-- report_name
	'rest_portfolio_planner_updates',				-- report_code
	'intranet-portfolio-planner',					-- package_key
	310,								-- report_sort_order
	(select menu_id from im_menus where label = 'reporting-rest'),	-- parent_menu_id
	''
);

update im_reports set
       report_description = 'Shows PMs who have not yet confirmed a change in their project schedule.',
       report_sql = '
select	wfc.case_id,
	wfc.object_id as project_id,
	acs_object__name(wfc.object_id) as project_name,
	wft.workflow_key,
	wft.transition_key,
	wfta.party_id as user_id,
	im_name_from_user_id(wfta.party_id) as user_name,
	im_email_from_user_id(wfta.party_id) as user_email
from	portfolio_planner_change_cases ppcc, 
	wf_cases wfc,
	wf_tasks wft
	LEFT OUTER JOIN wf_task_assignments wfta ON (wft.task_id = wfta.task_id)
where	ppcc.case_id = wfc.case_id and
	wft.case_id = wfc.case_id and
	wft.state != ''finished'' and
	transition_key = ''update'''
where report_code = 'rest_portfolio_planner_updates';

SELECT acs_permission__grant_permission(
	(select menu_id from im_menus where label = 'rest_portfolio_planner_updates'),
	(select group_id from groups where group_name = 'Employees'),
	'read'
);



---------------------------------------------------------
-- REST Data-Sources
--
-- These reports are portfolio-planner specific, so we do
-- not have to add them to sencha-core.
---------------------------------------------------------

-- List all inter-project dependencies on the server
--
SELECT im_report_new (
	'REST Inter-Project Task Dependencies',				-- report_name
	'rest_inter_project_task_dependencies',				-- report_code
	'sencha-core',							-- package_key
	220,								-- report_sort_order
	(select menu_id from im_menus where label = 'reporting-rest'),	-- parent_menu_id
	''
);

update im_reports set 
       report_description = 'Returns the list of inter-project dependencies',
       report_sql = '
select	d.dependency_id as id,
	d.*,
	main_one.project_id as main_project_id_one,
	main_one.project_name as main_project_name_one,
	main_two.project_id as main_project_id_two,
	main_two.project_name as main_project_name_two,
	p_one.project_id as task_one_id,
	p_one.project_name as task_one_name,
	p_one.start_date as task_one_start_date,
	p_one.end_date as task_one_end_date,
	p_two.project_id as task_two_id,
	p_two.project_name as task_two_name,
	p_two.start_date as task_two_start_date,
	p_two.end_date as task_two_end_date
from	im_timesheet_task_dependencies d,
	im_projects p_one,
	im_projects p_two,
	im_projects main_one,
	im_projects main_two
where	p_one.project_id = d.task_id_one and
	p_two.project_id = d.task_id_two and
	main_one.tree_sortkey = tree_root_key(p_one.tree_sortkey) and
	main_two.tree_sortkey = tree_root_key(p_two.tree_sortkey) and
	main_one.project_id != main_two.project_id
order by p_one.tree_sortkey, p_two.tree_sortkey
'       
where report_code = 'rest_inter_project_task_dependencies';

-- Relatively permissive
SELECT acs_permission__grant_permission(
	(select menu_id from im_menus where label = 'rest_inter_project_task_dependencies'),
	(select group_id from groups where group_name = 'Employees'),
	'read'
);





-----------------------------------------------------------
-- Component Plugin
--
-- Forum component on the ticket page itself

SELECT im_component_plugin__new (
	null, 'im_component_plugin', now(), null, null, null,
	'Portfolio Planner',		-- plugin_name - shown in menu
	'intranet-portfolio-planner',	-- package_name
	'top',				-- location
	'/intranet-portfolio-planner/index',	-- page_url
	null,				-- view_name
	10,				-- sort_order
	'im_portfolio_planner_component',	-- component_tcl
	'lang::message::lookup "" "intranet-portfolio-planner.Portfolio_Planner" "Portfolio Planner"'
);

SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins where plugin_name = 'Portfolio Planner' and page_url = '/intranet-portfolio-planner/index'),
	(select group_id from groups where group_name = 'Employees'),
	'read'
);


SELECT im_component_plugin__new (
	null, 'im_component_plugin', now(), null, null, null,
	'Project Portfolio Planner',		-- plugin_name - shown in menu
	'intranet-portfolio-planner',	-- package_name
	'bottom',				-- location
	'/intranet-resource-management/index',	-- page_url
	null,				-- view_name
	10,				-- sort_order
	'im_portfolio_planner_component',	-- component_tcl
	'lang::message::lookup "" "intranet-portfolio-planner.Portfolio_Planner" "Portfolio Planner"'
);

SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins 
	 where plugin_name = 'Project Portfolio Planner' and page_url = '/intranet-resource-management/index'),
	(select group_id from groups where group_name = 'Employees'),
	'read'
);

