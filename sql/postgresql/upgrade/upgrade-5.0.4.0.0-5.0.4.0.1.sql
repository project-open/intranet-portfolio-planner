SELECT acs_log__debug('/packages/intranet-portfolio-planner/sql/postgresql/upgrade/upgrade-5.0.4.0.0-5.0.4.0.1.sql','');

update im_component_plugins
set component_tcl = 'im_portfolio_planner_component -report_start_date $report_start_date -report_end_date $report_end_date -report_granularity $report_granularity -report_project_type_id "" -report_program_id $report_program_id -report_cost_center_id $report_cost_center_id'
where component_tcl like 'im_portfolio_planner_component%';
