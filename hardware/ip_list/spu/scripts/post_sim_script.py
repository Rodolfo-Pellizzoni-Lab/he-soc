import os
import sys
import copy
import math

def print_rw_req_dict(rw_req):
    print(f"      id: {rw_req['id']}")
    print(f"      addr: {rw_req['addr']}")
    print(f"      this_line_addr: {rw_req['this_line_addr']}")
    print(f"      next_line_addr: {rw_req['next_line_addr']}")
    print(f"      len: {rw_req['len']}")
    print(f"      size: {rw_req['size']}")
    print(f"      unaligned_transfer: {rw_req['unaligned_transfer']}")
    print(f"      size_in_bytes: {rw_req['size_in_bytes']}")
    print(f"      size_in_cachelines: {rw_req['size_in_cachelines']}")
    print(f"      start_cc: {rw_req['start_cc']}")
    print()

def write_py_o(final_output, req_queue, resp_queue, rw_len, TbNumMasters, is_read):
    for n in range(TbNumMasters):
        req_str = ''
        cur_q = list()

        rw_str = 'read' if is_read else 'write' 
        f = open(f"spu_log/py_{rw_str}_o.txt", "w")
        f.write("id,addr,this_line_addr,next_line_addr,len,size,unaligned_transfer,size_in_bytes,size_in_cachelines,start_cc,end_cc,resp_latency\n")
        f.close()
        for i in range(rw_len):
            resp_latency = str(int(resp_queue[n][i]['end_cc'] - req_queue[n][i]['start_cc']))
            req_str += str(req_queue[n][i]['id']) + ',' \
                            + str(req_queue[n][i]['addr']) + ',' \
                            + str(req_queue[n][i]['this_line_addr']) + ',' \
                            + str(req_queue[n][i]['next_line_addr']) + ',' \
                            + str(req_queue[n][i]['len']) + ',' \
                            + str(req_queue[n][i]['size']) + ',' \
                            + str(req_queue[n][i]['unaligned_transfer']) + ',' \
                            + str(req_queue[n][i]['size_in_bytes']) + ',' \
                            + str(req_queue[n][i]['size_in_cachelines']) + ',' \
                            + str(req_queue[n][i]['start_cc']) + ',' \
                            + str(resp_queue[n][i]['end_cc']) + ',' \
                            + str(resp_latency)
            req_str += '\n'

            req_dict = {
                'id': req_queue[n][i]['id'],
                'addr': req_queue[n][i]['addr'],
                'this_line_addr': req_queue[n][i]['this_line_addr'],
                'next_line_addr': req_queue[n][i]['next_line_addr'],
                'len': req_queue[n][i]['len'],
                'size': req_queue[n][i]['size'],
                'unaligned_transfer': req_queue[n][i]['unaligned_transfer'],
                'size_in_bytes': req_queue[n][i]['size_in_bytes'],
                'size_in_cachelines': req_queue[n][i]['size_in_cachelines'],
                'start_cc': req_queue[n][i]['start_cc'],
                'end_cc': resp_queue[n][i]['end_cc'], 
                'resp_latency': resp_latency
            }
            cur_q.append(req_dict)
        
        final_output.append(cur_q)

        # This is the golden output.
        f = open(f"spu_log/py_{rw_str}_o.txt", "a")
        f.write(req_str)
        f.close()

"""
    read/write_req.log have the following format:
        event_id,source_id,unaligned_transfer,size_of_burst(0)
        1,0,1,4
        1,1,1,3
"""
def parse_tb_spu_req_log(file_content, list_len, log_q):
    req_t = {
        'event_id': 0,
        'unaligned_transfer': 0,
        'size_in_bytes': 0,
        'size_in_cachelines': 0
    }

    # If 1 then size is in bytes, otherwise in cachelines.
    size_of_burst = 0
    print(len(file_content))

    for i in range(list_len+1):
        try:
            line = file_content[i]

            if (line[-1]=='\n'):
                line = line[:-1]

            split_line = line.split(',')

            # This line contains the labels.
            if i == 0:
                if split_line[3] == 'size_of_burst(0)':
                    size_of_burst = 0
                else:
                    size_of_burst = 1
            else:
                req = copy.deepcopy(req_t)
                req['event_id']             = int(split_line[0])
                req['unaligned_transfer']   = int(split_line[2])
                if size_of_burst:
                    req['size_in_bytes']        = int(split_line[3])
                    req['size_in_cachelines']   = -1
                else: 
                    req['size_in_bytes']        = -1
                    req['size_in_cachelines']   = int(split_line[3])
                log_q.append(req)
        except:
            print(f"Error: Entry #{i} not found!")
    # end loop

"""
    read/write_resp.log have the following format:
        event_id,source_id,resp_latency
        3,1,2131
        3,0,2668
"""
def parse_tb_spu_resp_log(file_content, num_resp, log_q):
    print(f" Called `parse_tb_spu_resp_log(file_content, {num_resp}, log_q)`")
    
    resp_t = {
        'event_id': 0,
        'resp_latency': 0,
    }

    for i in range(num_resp+1):
        line = file_content[i]

        if (line[-1]=='\n'):
            line = line[:-1]

        split_line = line.split(',')

        # This line contains the labels.
        if i == 0:
            pass
        else:
            resp = copy.deepcopy(resp_t)
            resp['event_id']     = split_line[0]
            resp['resp_latency'] = split_line[2]
            log_q.append(resp)
    # end loop

"""
    If there is a new read request, it will have the following format:
    558000> ID: 1d AR on channel: LEN: 181: SIZE: 2: ADDR:       1095
    [   0            1     2           3           4      5      6      7         8    ]
    ['558000> ID', '1d', 'AR on channel', 'LEN', '181', 'SIZE', '2', 'ADDR', '    1095']

    If there is a new write request, it will have the following format:
    558000> ID: 1d AW on channel: LEN: 181: SIZE: 2: ADDR:       1095: ATOP: 000000
    [   0            1     2           3           4      5      6      7         8         9       10   ]
    ['558000> ID', '1d', 'AR on channel', 'LEN', '181', 'SIZE', '2', 'ADDR', '    1095', 'ATOP', '000000']
"""
def parse_ax_line(rw_req, line, CacheCfg, TbClkPeriod): 
    split_line  = line.split(': ')
    # Timestamp.
    time        = int(split_line[0].split(">")[0])

    rw_req['start_cc']          = int(time / (TbClkPeriod*1000))
    rw_req['id']                = split_line[1]
    rw_req['len']               = int(split_line[4])
    rw_req['size']              = split_line[6]
    # Burst in bytes.
    rw_req['size_in_bytes']     = int(int(split_line[4])+1) << int(split_line[6])
    
    # Burst in cachelines.
    req_addr                    = int(split_line[8].replace(' ', ''))
    this_line_addr              = int(req_addr / (CacheCfg['NumBytesPerBlock'] * CacheCfg['NumBlocksPerLine']))
    this_line_addr              = int(this_line_addr * (CacheCfg['NumBytesPerBlock'] * CacheCfg['NumBlocksPerLine']))
    next_line_addr              = this_line_addr + int(2**(math.log2(CacheCfg['NumBytesPerBlock'] * CacheCfg['NumBlocksPerLine'])))
    
    rw_req['addr']              = hex(req_addr)
    rw_req['this_line_addr']    = hex(this_line_addr)
    rw_req['next_line_addr']    = hex(next_line_addr)

    if (req_addr != this_line_addr):
        rw_req['unaligned_transfer'] = 1
    else:
        rw_req['unaligned_transfer'] = 0

    bytes_on_cur_line   = next_line_addr - req_addr
    bytes_left          = rw_req['size_in_bytes'] - bytes_on_cur_line        
    cachelines_affected = 1
    if (bytes_left > 0):
        cachelines_affected += 1 + int(bytes_left / 2**(math.log2(CacheCfg['NumBytesPerBlock'] * CacheCfg['NumBlocksPerLine'])))
    rw_req['size_in_cachelines'] = cachelines_affected

    return rw_req

"""
    Read packets have the following format:
    3680000> ID: 1f: R:          0: of 182: LAST: 0: ATOP: 000000
    [     0          1    2        3           4         5     6     7        8    ]
    ['3680000> ID', '1f' 'R', '         0', 'of 182', 'LAST', '0', 'ATOP', '000000']

    Write packets have the following format (same as read):
    3680000> ID: 0e: W:          0: of 124: LAST: 0: ATOP: 000000
    [     0          1    2        3           4         5     6     7        8    ]
    ['3680000> ID', '0e' 'W', '         0', 'of 124', 'LAST', '0', 'ATOP', '000000']
"""
def parse_xLast_line(rw_resp, line, TbClkPeriod):
    split_line        = line.split(': ')
    # Timestamp.
    time              = int(split_line[0].split(">")[0])
    rw_resp['id']     = split_line[1]
    rw_resp['end_cc'] = int(time / (TbClkPeriod*1000))

    return rw_resp

"""
    Write response (B) packets have the following format (same as read):
    14710000> ID: 0e: B recieved
    [     0          1         2    ]
    ['3680000> ID', '0e' 'B recived']
"""
def parse_b_line(rw_resp, line, TbClkPeriod):
    split_line        = line.split(': ')
    # Timestamp.
    time              = int(split_line[0].split(">")[0])
    rw_resp['id']     = split_line[1]
    rw_resp['end_cc'] = int(time / (TbClkPeriod*1000))

    return rw_resp

def parse_log_files(TbNumMasters, TbNumRd, TbNumWr, TbClkPeriod=10, DEBUG=3): 
    cwd = os.getcwd()
    dir_name = "axi_log"
    dir_path = os.path.join(cwd, dir_name)
    dir_list = os.listdir(dir_path)

    CacheCfg = {
        'SetAssociativty': 8,
        'NumLines': 256,
        'NumBlocksPerLine': 8,
        'NumBytesPerBlock': 8   # Each block is 64-bit.
    }

    rw_req_t = {
        'id': 0,
        'addr': 0,
        'this_line_addr': 0,
        'next_line_addr': 0,
        'len': 0,
        'size': 0,
        'unaligned_transfer': 0,
        'size_in_bytes': 0,
        'size_in_cachelines': 0,
        'start_cc': 0
    }

    rw_resp_t = {
        'id': 0,
        'end_cc': 0
    }

    # Create empty queues to hold log request and response packets.
    read_req_queue = []
    write_req_queue = []
    read_resp_queue = []
    write_resp_queue = []

    for m in range(TbNumMasters):
        read_req_per_master_queue = []
        write_req_per_master_queue = []
        read_resp_per_master_queue = []
        write_resp_per_master_queue = []

        for i in range(TbNumRd):
            rw_req  = copy.deepcopy(rw_req_t)
            rw_resp = copy.deepcopy(rw_resp_t)
            read_req_per_master_queue.append(rw_req)
            read_resp_per_master_queue.append(rw_resp)
        
        for i in range(TbNumWr):
            rw_req  = copy.deepcopy(rw_req_t)
            rw_resp = copy.deepcopy(rw_resp_t)
            write_req_per_master_queue.append(rw_req)
            write_resp_per_master_queue.append(rw_resp)
        
        read_req_queue.append(read_req_per_master_queue)
        write_req_queue.append(write_req_per_master_queue)
        read_resp_queue.append(read_resp_per_master_queue)
        write_resp_queue.append(write_resp_per_master_queue)

    n_master = 0

    for dir in dir_list:
        # Don't need to parse both slave and master log files, since they both contain the same set of requests.
        # Only parsing master log files because they give a more accurate count of request latency.
        if dir.find("master") != -1:
            if (DEBUG >= 3):
                print(f" Parsing files in directory: {dir}.")
            sub_dir = os.path.join(dir_path, dir)
            sub_dir_list = os.listdir(sub_dir)
            
            num_r  = 0
            num_b  = 0
            num_ar = 0
            num_aw = 0
            for file in sub_dir_list: 
                if (DEBUG >= 3):
                    print()
                    print(f"  Parsing file: {file}.")
                
                # Read file into file_content.
                with open(f"{os.path.join(dir_path, dir, file)}", 'r') as f:
                    file_content = f.readlines()
                
                for idx, line in enumerate(file_content):
                    # First line in each file is as follows:
                    # 'This is the read log file for ID: 1f'
                    if (idx == 0):
                        pass
                    else: 
                        if (line[-1]=='\n'):
                            line = line[:-1]
                        split_line  = line.split(': ')
                        # Timestamp.
                        time        = int(split_line[0].split(">")[0])

                        ar_find     = line.find('AR')
                        aw_find     = line.find('AW')
                        r_find      = line.find('R')
                        b_find      = line.find('B')      

                        rw_req      = copy.deepcopy(rw_req_t)
                        rw_resp     = copy.deepcopy(rw_resp_t)                                    
                        
                        if (ar_find != -1):
                            # Parse ax_chan specific lines.
                            parse_ax_line(rw_req, line, CacheCfg, TbClkPeriod)
                            # Add output dict to the queue.
                            read_req_queue[n_master][num_ar] = rw_req

                            if (DEBUG >= 3):
                                print(f"    Master #{n_master}:: Read req #{num_ar}")
                                print_rw_req_dict(rw_req)
                            num_ar += 1

                        elif (aw_find != -1):
                            # Parse ax_chan specific lines.
                            parse_ax_line(rw_req, line, CacheCfg, TbClkPeriod)
                            # Add output dict to the queue.
                            write_req_queue[n_master][num_aw] = rw_req

                            if (DEBUG >= 3):
                                print(f"    Master #{n_master}:: Write req #{num_aw}")
                                print_rw_req_dict(rw_req)                                
                            num_aw += 1
                        
                        elif (r_find != -1):
                            # Last bit.
                            if(split_line[6] == '1'):
                                # Parse x_chan specific lines with `last=1`.
                                parse_xLast_line(rw_resp, line, TbClkPeriod)                                
                                # Add output dict to the queue.
                                read_resp_queue[n_master][num_r] = rw_resp
                                
                                if (DEBUG >= 3):
                                    print(f"    Master #{n_master}:: Read resp #{num_r}")
                                    print(f"      id: {rw_resp['id']}")
                                    print(f"      end_cc: {rw_resp['end_cc']}")
                                    print()
                                num_r += 1

                        elif (b_find != -1):
                            # Parse b_chan specific lines.
                            parse_xLast_line(rw_resp, line, TbClkPeriod)                                
                            # Add output dict to the queue.
                            write_resp_queue[n_master][num_b] = rw_resp
                                
                            if (DEBUG >= 3):
                                    print(f"    Master #{n_master}:: Write resp #{num_b}")
                                    print(f"      id: {rw_resp['id']}")
                                    print(f"      end_cc: {rw_resp['end_cc']}")
                                    print()
                            num_b += 1
                    # end loop for writing read packets.                    
    # end loop

    # Write outputs to the `py.txt` and to `final_rd/wr`.
    final_rd = list()
    final_wr = list()
    write_py_o(final_rd, read_req_queue, read_resp_queue, TbNumRd, TbNumMasters, is_read=1)
    write_py_o(final_wr, write_req_queue, write_resp_queue, TbNumWr, TbNumMasters, is_read=0)

    # Sort for read request queues based on start time and for read response queues based on end time.
    # This is because the testbench prints a new request `AR` when it starts and only prints the response when they end.
    # By testbench, I mean the output printed in `spu_log/read_req/resp.log`.
    # 
    # Note: Since the read request (reads are not in-order) that started first does not necessarily finish 
    #       first. This means that the `read_resp.log` of `tb_spu.sv` does not map correctly to its `read_req.log`.
    # Example: A read with ID=1f and one with ID=08 start at 1 and 3 cc respectively.
    #          Read with ID=08 ends at 6 cc and ID=1f ends at 17 cc. Currently the queues are being sorted 
    #          independently. The read_req.log would be: [{1f, einfo}, {08, einfo}] and read_resp.log would be: [{08, einfo}, {1f, einfo}].
    #          Of course, the IDs here are omitted as the SPU output does not contain the transaction ID (it has master/source ID 
    #          but they are concatenated from the transaction ID.)
    #
    # This does not happen with writes because writes have to be ordered as the `WD` channel does not have an ID signal.
    #
    # This is why the final read queue must be sorted twice, according to `start_cc` to compare with the read_requests and then
    # according to `end_cc` to compare with read_responses.
    final_rd_req  = copy.deepcopy(final_rd)
    final_rd_resp = copy.deepcopy(final_rd)
    for n in range(TbNumMasters):
        sorted_rd_req_q  = sorted(final_rd[n], key=lambda d: d['start_cc'])
        sorted_rd_resp_q = sorted(final_rd[n], key=lambda d: d['end_cc'])
        sorted_wr_q      = sorted(final_wr[n], key=lambda d: d['start_cc'])

        final_rd_req[n]  = sorted_rd_req_q
        final_rd_resp[n] = sorted_rd_resp_q
        final_wr[n]      = sorted_wr_q

    cwd = os.getcwd()
    dir_name = "spu_log"
    dir_path = os.path.join(cwd, dir_name)
    dir_list = os.listdir(dir_path)

    if (DEBUG >= 1):
        print("\n =============")
        print("    OUTUPTS")
        print(" =============\n")

    total_err = 0
    total_err_resp = 0
    for dir in dir_list:
        err_count = 0
        if dir in ['py_read_o.txt', 'py_write_o.txt']:
            continue

        # Read file into file_content.
        with open(f"{os.path.join(dir_path, dir)}", 'r') as f:
            file_content = f.readlines()

        if dir in ['read_req.log', 'write_req.log']:
            log_q = []

            rw     = 'Write'
            rw_len = TbNumWr
            queue  = final_wr
            if dir == 'read_req.log':
                rw     = 'Read'
                rw_len = TbNumRd
                queue  = final_rd_req
            
            # Parse the request log files printed by `tb_spu.sv`.
            if (DEBUG >= 2):
                print(f" Parsing `tb_spu.sv` output: {dir}.")
            parse_tb_spu_req_log(file_content, rw_len, log_q)
            for n in range(TbNumMasters):
                if (DEBUG >= 1):
                    print(f" ------------------------")
                    print(f" Master {n} => {dir}")
                    print(f" ------------------------")

                for i in range(rw_len):
                    # Check unaligned transfers.
                    if (queue[n][i]['unaligned_transfer'] != log_q[i]['unaligned_transfer']):
                        err_count += 1
                        print(f"  ERROR! {rw}_req (unaligned_transfer): Idx: {i}.")
                        print(f"    {n},{i}: {queue[n][i]['unaligned_transfer']} vs {log_q[i]['unaligned_transfer']}")
                        if (DEBUG >= 1):
                                print_rw_req_dict(queue[n][i])
                    elif (DEBUG >= 1):
                        if (i==0):
                            print(f"  {rw} request, unaligned_transfer.")
                        print(f"    {n},{i}: {queue[n][i]['unaligned_transfer']} vs {log_q[i]['unaligned_transfer']}")

                for i in range(rw_len):
                    # If -1 then the size is in cachlines.
                    if (log_q[i]['size_in_bytes'] == -1):
                        if (queue[n][i]['size_in_cachelines'] != log_q[i]['size_in_cachelines']):
                            err_count += 1
                            print(f"  ERROR! {rw}_req (size_in_cachelines): Idx: {i}.")
                            print(f"    {n},{i}: {queue[n][i]['size_in_cachelines']} vs {log_q[i]['size_in_cachelines']}")
                            if (DEBUG >= 1):
                                print_rw_req_dict(queue[n][i])
                        elif (DEBUG >= 1):
                            if (i==0):
                                print(f"  {rw} request, size_in_cachelines.")
                            print(f"    {n},{i}: {queue[n][i]['size_in_cachelines']} vs {log_q[i]['size_in_cachelines']}")
                    else:
                        if (queue[n][i]['size_in_bytes'] != log_q[i]['size_in_bytes']):
                            err_count += 1
                            print(f"  ERROR! {rw}_req (size_in_bytes): Idx: {i}.")
                            print(f"    {n},{i}: {queue[n][i]['size_in_bytes']} vs {log_q[i]['size_in_bytes']}")
                            if (DEBUG >= 1):
                                print_rw_req_dict(queue[n][i])
                        elif (DEBUG >= 1):
                            if (i==0):
                                print(f"  {rw} request, size_in_bytes.")
                            print(f"    {n},{i}: {queue[n][i]['size_in_bytes']} vs {log_q[i]['size_in_bytes']}")
                # end loop - rw_len = TbNumRd / TbNumWr
            total_err +=  err_count
            print(f"  Errors in {rw} request: {err_count}")
            # end loop - TbNumMasters
        # if - read_req.log / write_req.log

        if dir in ['read_resp.log', 'write_resp.log']:
            log_q = []

            rw     = 'Write'
            rw_len = TbNumWr
            queue  = final_wr
            if dir == 'read_resp.log':
                rw     = 'Read'
                rw_len = TbNumRd
                queue  = final_rd_resp
            
            # Parse the response log files printed by `tb_spu.sv`.
            if (DEBUG >= 2):
                print(f" Parsing `tb_spu.sv` output: {dir}, TbNum{rw}: {rw_len}")
            parse_tb_spu_resp_log(file_content, rw_len, log_q)

            for n in range(TbNumMasters):
                if (DEBUG >= 1):
                    print(f" ------------------------")
                    print(f" Master {n} => {dir}")
                    print(f" ------------------------")

                for i in range(rw_len):
                    # Check response latency.
                    delta = abs(int(queue[n][i]['resp_latency']) - int(log_q[i]['resp_latency']))
                    if (delta > 100):
                        err_count += 1
                        print(f"  ERROR! {rw}_req (resp_latency): Idx: {i}.")
                        print(f"    {n},{i}: {queue[n][i]['resp_latency']} vs {log_q[i]['resp_latency']} ({delta})")
                        if (DEBUG >= 1):
                                print_rw_req_dict(queue[n][i])
                    elif (DEBUG >= 1):
                        if (i==0):
                            print(f"  {rw} response, resp_latency.")
                        print(f"    {n},{i}: {queue[n][i]['resp_latency']} vs {log_q[i]['resp_latency']}")
                # end loop - rw_len = TbNumRd / TbNumWr
            total_err +=  err_count
            print(f"  Errors in {rw} response: {err_count}")
            # end loop - TbNumMasters
        # if - read_resp.log / write_resp.log
    print(f"   Total errors: {total_err}.")
    # end loop - Loops through all `tb_spu.sv` log files.
                        
if __name__=="__main__":
    # Note: It is important to remember that the output of the read requests from the SPU
    # is ordered according to the start time of each request. And read responses are ordered 
    # according to the end time.

    if len(sys.argv) == 1:
        TbNumMasters = 1
        TbNumRd      = 5
        TbNumWr      = 5
    else: 
        TbNumMasters = int(sys.argv[1])
        TbNumRd      = int(sys.argv[2])
        TbNumWr      = int(sys.argv[3])
    
    print(" Test arguments are:")
    print(f"  TbNumMasters: {TbNumMasters}")
    print(f"  TbNumRd:      {TbNumRd}")
    print(f"  TbNumWr:      {TbNumWr}")
    print()

    parse_log_files(TbNumMasters, TbNumRd, TbNumWr, DEBUG=3)
