require 'strscan'
class Whitespace
    def initialize
        # ファイル読み込み
        begin
            code = ARGF.readlines.join
            # puts @code
        rescue
            puts "ファイルがありません。"
        end

        # IMP表
        @imps = {
            "s"  => :stack,
            "ts" => :arithmetic,
            "tt" => :heap,
            "n"  => :flow,
            "tn" => :io
        }
        
        # s_スタック操作
        @imp_s = {
            "s"  => :push,
            "ns" => :top_copy_push,
            "ts" => :n_copy_push,
            "nt" => :top2_change,
            "nn" => :top_del,
            "tn" => :bottom_n_del
        }

        # ts_算術演算
        @imp_ts = {
            "ss" => :add,
            "st" => :sub,
            "sn" => :mul,
            "ts" => :div,
            "tt" => :rem
        }

        # ts_ヒープアクセス
        @imp_tt = {
            "s" => :push_heap,
            "t" => :h_pull_s_push
        }

        # n_フロー制御
        @imp_n = {
            "ss" => :label,
            "st" => :subroutine,
            "sn" => :jump,
            "ts" => :top0_jump,
            "tt" => :top_minus_jump,
            "tn" => :end_sub,
            "nn" => :exit
        }

        # tn_入出力
        @imp_tn = {
            "ss" => :out_let_top,
            "st" => :out_num_top,
            "ts" => :in_let_h_push,
            "tt" => :in_num_h_push
        }

        # スタック
        @stack = []
        # ヒープ
        @heap = []

        # 字句解析呼び出し
        tokenize(code)
    end

    # 字句解析
    def tokenize(code)
        result = []
        scanner = StringScanner.new(code)

        while true
            # IMP切り出し　見えない
            is_imp = scanner.scan(/\A( |\n|\t[ \n\t])/)
            break if !is_imp

            unless is_imp
                raise Exception, "undefined imp"
            end
            # impをs,t,nに変換
            trans_imp = trans_stn(is_imp)
            # impをシンボルに変換
            imp = @imps[trans_imp]
            # puts imp # デバッグ


            # コマンド切り出し　見えない
            is_cmd = find_command(scanner, trans_imp) # コマンドを文字に変換
            # コマンドをs,t,nに変換
            trans_cmd = trans_stn(is_cmd)
            # コマンドをシンボルに変換
            imp_what = instance_variable_get("@imp_#{trans_imp}")
            command = imp_what[trans_cmd]
            # puts command # デバッグ


            # パラメータ切り出し(必要なら) 見えない
            is_prm = find_parameter(scanner, trans_imp, trans_cmd)
            # パラメータを文字に変換
            param = trans_stn(is_prm)
            # puts param # デバッグ


            result << imp << command << param

        end
        p result
        parsing(result)
    end

    # s,t,nの文字に変換
    def trans_stn(space)
        return if !space

        result = []
        # 一文字ずつ
        space.each_char do |stn|
            case stn
            when " "
                result << "s"
            when /\t/
                result << "t"
            when /\n/
                result << "n"
            end
        end
        result.join
    end

    # コマンド切り出し
    def find_command(scanner, imp)
        case imp
        when "s"
            result = scanner.scan(/\A( |\n[ \n\t]|\t[ \n])/)
        when "ts"
            result = scanner.scan(/\A( [ \t\n]|\t[ \t])/)
        when "tt"
            result = scanner.scan(/\A( |\t)/)
        when "n"
            result = scanner.scan(/\A( [ \t\n]|\t[ \t\n]|\n\n)/)
        when "tn"
            result = scanner.scan(/\A( [ \t]|\t[ \t])/)
        end

        unless result
            raise StandardError, 'undefined command'
        else
            result # 見えない
        end
    end

    # パラメータ切り出し
    def find_parameter(scanner, imp, cmd)
        is_match_s = (cmd =~ /\A(s|t[ns])/)
        is_match_n =  (cmd =~ /\A(s[nst]|t[st])/)

        if (imp == "s" && is_match_s) || (imp == "n" && is_match_n) then
            result = scanner.scan(/\A([ \t]+\n)/)

            unless result
                raise StandardError, 'undefined parameter'
            else
                result.chop # 見えない
            end
        end

    end

    # 構文解析
    def parsing(tokenize)
        result = []
        n=3
        tokenize.each_slice(n) do |imp, command, param|
            #パラメータを数字に変換する
            if param != nil then
                param = change_num(param) 
            end
            result << [imp, command, param]
        end
        p result
        semantic_analysis(result)
    end

    # パラメータを数値に変換
    def change_num(param)
        result = []
        param.chars.each do |tab_spa|
            case tab_spa
            when s
                result << '0'
            when t
                result << '1'
            end
        end
        result.join
    end

    # 意味解析
    def semantic_analysis(parsing)
        i=0
        length = parsing.length
        while length > i
            case parsing[i][0]
            when :stack
                stack(parsing[i][1], parsing[i][2])
            when :arithmetic
                arithmetic(parsing[i][1])
            when :heap
                heap(parsing[i][1])
            when :flow
                flow(parsing[i][1], parsing[i][2])
            when :io
                io(parsing[i][1])
            end
            i=i+1
        end
    end

    # スタック操作
    def stack(cmd, param)
        case cmd
        when :push
            @stack.push(param)
        when :top_copy_push
            @stack.push(@stack.last)
        when :n_copy_push
            @stack.push(@stack[param])
        when :top2_change
            @stack.push(@stack.slice!(-2))
        when :top_del
            @stack.pop
        when :bottom_n_del
            @stack.delete_at(prmt)
        end
    end

    # 算術演算
    def arithmetic(cmd)
        f_elm = @stack.pop
        s_elm = @stack.pop
        case cmd
        when :add
            @stack.push(s_elm + f_elm)
        when :sub
            @stack.push(s_elm - f_elm)
        when :mul
            @stack.push(s_elm * f_elm)
        when :div
            @stack.push(s_elm / f_elm)
        when :rem
            @stack.push(s_elm % f_elm)
        end
    end

    # ヒープアクセス
    def heap(cmd)
        case cmd
        when :push_heap
            @heap
        when :h_pull_s_push
            @heap
        end
    end

    # フロー制御
    def flow(cmd, param)
        case cmd
        when :label
            pc=pc+1
        when :subroutine
        when :jump
            n = 0
            @tokens.each { |i,c,p|
                if c == :label and p == prmt then
                    pc = n+1
                end
                n = n + 1
            }
        when :top0_jump
        when :top_minus_jump
        when :end_sub
        when :exit
        end 
    end

    #入出力
    def io(cmd)
        when :out_let_top
            STDOUT << @stack.pop.chr
            execute(tokens, pc + 1, @stack, @heap, subroutine)
        when :out_num_top
            STDOUT << @stack.pop
            execute(tokens, pc + 1, @stack, @heap, subroutine)
        when :in_let_h_push
            @heap[@stack.pop] = STDIN.getc.ord
            execute(tokens, pc + 1, @stack, @heap, subroutine)
        when :in_num_h_push
            @heap[@stack.pop] = STDIN.gets.to_i
            execute(tokens, pc + 1, @stack, @heap, subroutine)
        end
    end

end

Whitespace.new