
    # given a string (name) and address (symbol), construct and
    # return a hash with a symbol table entry in it
    def make_symbol(name="", cfa=0)
        # values calculated by pearson.rb
        # 14..22		102 162 3 150 98 88 207 149
        pearson = [102, 162, 3, 150, 98, 88, 207, 149]
		psize=pearson.length-1

        c1 = [cfa.to_i].pack("S<")
    #   puts c1
        c2 = [name.length].pack("C")
    #   puts c2
        c3 = name.bytes.pack("C")
        nfa = [name.length].pack("C")+name
        data = [cfa.to_i].pack("S<")+nfa
        
        hash=name.length
		name.each_byte { |char|
			hash = char^pearson[hash&psize]
		}
        eornybble = (hash & 15)^((hash ^ 240)/16)
        t = { 
        name: name ,
        data: data , 
        len: name.length ,
        hash1: eornybble }
        return t
    end

    # given a string from the .a65 source code, like
    #     .asc "BLOC","K"|bit7
    # returns a string containing just the ascii name of this word, e.g. "DUP"
    def parse_name(nfaline)
        while (nfaline =~ /(.*)\|bit[67]$/)
            nfaline = $1
        end
        while (nfaline =~ /^\ *\.asc\ *(.*)/)
            nfaline = $1
        end
        while (nfaline =~ /(.*),(\d+)$/)
            nfaline = $1+',"'+$2.to_i.chr+'"'
        end
        while (nfaline =~ /\"(.+)\",'(\")'$/)
            nfaline = $1 + $2
        end
        while (nfaline =~ /\"(.+)\",'(\")',\"(.+)\"$/)
            nfaline = $1 + $2 + $3
        end
        while (nfaline =~ /\"(.+)\",\"(.)\"$/)
            nfaline = $1 + $2
        end
        while (nfaline =~ /\"(.+)\"$/)
            nfaline = $1
        end
        return nfaline
    end

    # read the symbol table generated by the xa65 assembler into a hash
    # for translating the symbol into its hex address
    symbols = Hash.new
    result = File.open('pettil.lab','r') do |f|
        while (line = f.gets) do
            line.chomp!
            a = line.split(",")
            symbols[a[0]] = a[1].hex
        end
    end

=begin

#ifdef HEADERS
rehashlfa
    .byt $de,$ad
    .byt (_rehash-*-1)|bit7
    .asc "REHAS","H"|bit7
#endif
_rehash
#include "enter.i65"
    .word exit

=end
    # Scan the assembler source file for headers, that look something like 
    # the block up above this comment.  parse them and create a binary
    # output file with the symbol table in it
    b=Hash.new
    ["pettil.a65","editor.a65"].each do |filename|
        infile = File.open(filename,'r')
        while (line = infile.gets) do
            if (line.chomp == "\#ifdef HEADERS")
                # grab the next few lines
                lfasymbol = infile.gets
                dead = infile.gets
                namelen = infile.gets
                nfaline = infile.gets   # this is useful
                endifline = infile.gets
                symbol = infile.gets    # so is this
                
                # make a few validation checks
                if !(dead =~ /^\s+\.byt \$de,\$ad$/)
                    puts "uh oh", symbol, dead
                end
                if !(namelen =~ /^\s+\.byt\ \(#{symbol.chomp}-\*-1\)(\|bit6|\|bit7)+$/)
                    puts "uh oh", symbol, namelen
                end
                if !(endifline.chomp =~ /^\#endif$/)
                    puts "uh oh",symbol, endifline
                end

                # turn this:    .asc "REHAS","H"|bit7
                # into this:    REHASH
                nfaline = parse_name(nfaline)
                puts nfaline            # feed this to pearson.rb

                # we should have enough (a name and an address)
                a = make_symbol(nfaline, symbols[symbol.chomp])
                b[a[:name]] = a
            end
        
        end
    end

    symfile = File.open("pettil.sym",'w')
    Hash[b.sort_by { | k, v | v[:hash1]*32+v[:len] }].each do |h|
        a = h[1][:data].bytes
        symfile.write a.pack("C*")
    end
