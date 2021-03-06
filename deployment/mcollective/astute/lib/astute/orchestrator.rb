module Astute
  class Orchestrator
    def initialize(deploy_engine=nil, log_parsing=false)
      @deploy_engine = deploy_engine ||= Astute::DeploymentEngine::NailyFact
      if log_parsing
        @log_parser = LogParser::ParseDeployLogs.new
      else
        @log_parser = LogParser::NoParsing.new
      end
    end

    def node_type(reporter, task_id, nodes, timeout=nil)
      context = Context.new(task_id, reporter)
      uids = nodes.map {|n| n['uid']}
      systemtype = MClient.new(context, "systemtype", uids, check_result=false, timeout)
      systems = systemtype.get_type
      return systems.map {|n| {'uid' => n.results[:sender],
                               'node_type' => n.results[:data][:node_type].chomp}}
    end

    def deploy(up_reporter, task_id, nodes, attrs)
      raise "Nodes to deploy are not provided!" if nodes.empty?
      # Following line fixes issues with uids: it should always be string
      nodes.map { |x| x['uid'] = x['uid'].to_s }
      proxy_reporter = ProxyReporter.new(up_reporter)
      context = Context.new(task_id, proxy_reporter, @log_parser)
      deploy_engine_instance = @deploy_engine.new(context)
      Astute.logger.info "Using #{deploy_engine_instance.class} for deployment."
      begin
        @log_parser.prepare(nodes)
      rescue Exception => e
        Astute.logger.warn "Some error occurred when prepare LogParser: #{e.message}, trace: #{e.backtrace.inspect}"
      end
      deploy_engine_instance.deploy(nodes, attrs)
    end

    def remove_nodes(reporter, task_id, nodes)
      context = Context.new(task_id, reporter)
      node_removal = NodeRemoval.new
      return node_removal.remove(context, nodes)
    end

    def verify_networks(reporter, task_id, nodes, networks)
      context = Context.new(task_id, reporter)
      result = Network.check_network(context, nodes, networks)
      return result
    end
  end
end
