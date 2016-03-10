-- upgrade-5.0.0.0.1-5.0.0.0.2.sql
SELECT acs_log__debug('/packages/intranet-portfolio-planner/sql/postgresql/upgrade/upgrade-5.0.0.0.1-5.0.0.0.2.sql','');



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

